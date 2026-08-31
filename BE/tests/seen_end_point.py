import main

for route in main.app.routes:
    methods = getattr(route, "methods", None)
    path = getattr(route, "path", None)
    name = getattr(route, "name", None)

    if methods and path:
        print(f"{','.join(sorted(methods)):20} {path:60} {name}")
