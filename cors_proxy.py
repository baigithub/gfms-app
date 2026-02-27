#!/usr/bin/env python3
"""
CORS代理服务器 - 使用requests库，更稳定
"""
import http.server
import socketserver
import requests
import json
import sys
import threading

import os
PORT = int(os.environ.get('PORT', 8080))
TARGET_HOST = "http://localhost:8000"
TIMEOUT = 10

class CORSProxyHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    
    def log_message(self, format, *args):
        print(f"{self.client_address[0]} - - [{self.log_date_time_string()}] {format % args}")
        sys.stdout.flush()

    def do_GET(self):
        self.proxy_request("GET")

    def do_POST(self):
        self.proxy_request("POST")

    def do_PUT(self):
        self.proxy_request("PUT")

    def do_DELETE(self):
        self.proxy_request("DELETE")

    def do_PATCH(self):
        self.proxy_request("PATCH")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Allow-Credentials', 'true')
        self.send_header('Access-Control-Max-Age', '3600')
        self.end_headers()

    def proxy_request(self, method):
        target_url = TARGET_HOST + self.path
        
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            headers = {}
            for h in ['Content-Type', 'Authorization', 'X-Client-Type', 'X-Requested-With', 'Accept']:
                if self.headers.get(h):
                    headers[h] = self.headers.get(h)
            
            response = requests.request(
                method=method,
                url=target_url,
                data=body,
                headers=headers,
                timeout=TIMEOUT
            )
            
            self.send_response(response.status_code)
            
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', '*')
            self.send_header('Access-Control-Allow-Credentials', 'true')
            
            response_body = response.content
            
            self.send_header('Content-Length', str(len(response_body)))
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            
            self.end_headers()
            self.wfile.write(response_body)
            
        except requests.exceptions.Timeout:
            self.send_error(504, "Gateway Timeout")
        except Exception as e:
            print(f"  [ERROR] {e}")
            sys.stdout.flush()
            self.send_error(500, str(e))

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

print(f"Starting CORS proxy server on port {PORT}")
print(f"Proxying requests to {TARGET_HOST}")
print(f"API will be available at http://localhost:{PORT}/api/*")
sys.stdout.flush()

server = ThreadedHTTPServer(("", PORT), CORSProxyHandler)
server.serve_forever()
