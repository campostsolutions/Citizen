import adsk.core, adsk.fusion, adsk.cam, os

def startApp(context):
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface
        
        # Simple test - just show a message
        ui.messageBox("Add-in loaded successfully!", "Test")
        
    except Exception as e:
        app = adsk.core.Application.get()
        ui = app.userInterface
        ui.messageBox(f"Error: {str(e)}", "Error")

def endApp(context):
    pass
