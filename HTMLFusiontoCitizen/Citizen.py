import sys
import os

# Add the current directory to the Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

def run(context):
    try:
        # Try to import and run startApp from main
        import main
        main.startApp(context)
    except Exception as e:
        # If import fails, show error message
        import adsk.core
        app = adsk.core.Application.get()
        ui = app.userInterface
        ui.messageBox(f"Error loading add-in: {str(e)}")
    
def stop(context):
    try:
        # Try to import and run endApp from main
        import main
        main.endApp(context)
    except Exception as e:
        # If import fails, show error message
        import adsk.core
        app = adsk.core.Application.get()
        ui = app.userInterface
        ui.messageBox(f"Error stopping add-in: {str(e)}")
