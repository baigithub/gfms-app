#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import urllib.parse
import json

PORT = 8082
API_BASE = "http://localhost:8000"

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/api/'):
            target_path = self.path
            if '?' in self.path:
                path, query = self.path.split('?', 1)
                target_path = f"{path}?{query}"
            else:
                target_path = self.path
            
            url = f"{API_BASE}{target_path}"
            
            headers = {}
            for key, value in self.headers.items():
                if key.lower() not in ['host']:
                    headers[key] = value
            
            print(f"Proxy GET: {url}")
            print(f"Headers: {headers}")
            
            try:
                req = urllib.request.Request(url, headers=headers)
                response = urllib.request.urlopen(req)
                
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(key, value)
                self.end_headers()
                
                self.wfile.write(response.read())
            except Exception as e:
                print(f"Proxy error: {e}")
                self.send_error(502, f"Bad Gateway: {e}")
        else:
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/api/'):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else b''
            
            url = f"{API_BASE}{self.path}"
            
            headers = {}
            for key, value in self.headers.items():
                if key.lower() not in ['host', 'content-length']:
                    headers[key] = value
            
            print(f"Proxy POST: {url}")
            print(f"Headers: {headers}")
            
            try:
                req = urllib.request.Request(url, data=body, headers=headers, method='POST')
                response = urllib.request.urlopen(req)
                
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in ['transfer-encoding', 'connection']:
                        self.send_header(key, value)
                self.end_headers()
                
                self.wfile.write(response.read())
            except Exception as e:
                print(f"Proxy error: {e}")
                self.send_error(502, f"Bad Gateway: {e}")
        else:
            self.send_error(405, "Method Not Allowed")

class CustomProxyHandler(ProxyHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='build/web', **kwargs)

print(f"Starting proxy server on port {PORT}")
print(f"API requests will be proxied to {API_BASE}")
print(f"Static files served from: build/web")

with socketserver.TCPServer(("", PORT), CustomProxyHandler) as httpd:
    httpd.serve_forever()
