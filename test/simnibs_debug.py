import sys
import os

print("Python executable:", sys.executable)
print("Python version:", sys.version)
print("PYTHONPATH:", os.environ.get("PYTHONPATH", "Not set"))

try:
    import simnibs
    print("SimNIBS imported successfully!")
    print("SimNIBS path:", simnibs.__file__)
except ImportError as e:
    print("SimNIBS import error:", e)

    # Try to find simnibs in common locations
    for path in sys.path:
        potential_simnibs = os.path.join(path, "simnibs")
        if os.path.exists(potential_simnibs):
            print(f"Found potential simnibs at: {potential_simnibs}")
