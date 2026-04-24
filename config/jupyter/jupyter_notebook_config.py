# jupyter_notebook_config.py — configured for local-only, tokenless access
c = get_config()
# Only listen on localhost for security
c.NotebookApp.ip = '127.0.0.1'
# Do not require a token for local use (be careful if you change ip)
c.NotebookApp.token = ''
# Do not open browser by default
c.NotebookApp.open_browser = False
# Use a sensible default port
c.NotebookApp.port = 8888
