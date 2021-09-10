import http.server
import socketserver
import os

PORT = 8001
Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("",PORT), Handler) as httpd:
    print('serving at 127.0.0.1:{}\nfiles: {}'.format(PORT, os.listdir()))
    httpd.serve_forever()
