import traceback
import adsk.core, adsk.fusion, adsk.cam, os, json, urllib.request # type: ignore
from datetime import datetime, timedelta
from os import listdir
from os.path import isfile, join
import sys
import time
import tempfile

# global variables
global _get, selected_post, L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts
_get = {}
handlers = []
selected_post = None
L1_posts = []
L2_posts = []
L3_posts = []
L320_posts = []
Miyano_posts = []
other_posts = []
posts_fldr = None
output_fldr = None

def get_output_folder():
    """
    Get the output folder path. Always uses AppData\Local\FusionToCitizen
    to ensure compatibility with other applications that expect files in this location.
    """
    # Always use AppData\Local\FusionToCitizen for compatibility with other apps
    appdata_local = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'FusionToCitizen')
    
    # If LOCALAPPDATA is not available, construct the path manually
    if not appdata_local or not os.path.exists(os.path.dirname(appdata_local)):
        appdata_local = os.path.join(os.path.expanduser('~'), 'AppData', 'Local', 'FusionToCitizen')
    
    return appdata_local

def messageBox(text: str, title: object = None) -> object:
    if not title:
        title = 'Message'
    app = adsk.core.Application.get()
    ui = app.userInterface
    ui.messageBox(text, title)
    return text

def startApp(context):
    global posts_fldr, output_fldr

    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface
        
        # Debug: Check if we can access the UI
        if not ui:
            raise Exception("Could not access Fusion 360 user interface")
        
        if sys.platform == 'darwin':
            ui.messageBox('Unfortunately the Citizen addin only works on Windows')
            return
        
        # Initialize posts folder
        posts_fldr = os.path.join(os.path.dirname(__file__), 'posts')
        # Use flexible output folder path that works for any user
        output_fldr = get_output_folder()
        
        # Debug: Show which output folder is being used
        print(f"Citizen Post Processor: Using output folder: {output_fldr} (for compatibility with other applications)")
        
        # Ensure posts folder exists
        if not os.path.exists(posts_fldr):
            os.makedirs(posts_fldr, exist_ok=True)
        
        # Ensure output folder exists
        if not os.path.exists(output_fldr):
            os.makedirs(output_fldr, exist_ok=True)
        
        # Debug: Check if folders were created successfully
        if not os.path.exists(posts_fldr):
            raise Exception(f"Could not create posts folder: {posts_fldr}")
        if not os.path.exists(output_fldr):
            raise Exception(f"Could not create output folder: {output_fldr}")
        
        # Clean up any existing commands first
        endApp(context)
        
        # Small delay to ensure cleanup is complete
        time.sleep(0.5)

        cmdDefs = ui.commandDefinitions
        if not cmdDefs:
            raise Exception("Could not access command definitions")
            
        # Get CAM Action Panel
        CAMActionPan = ui.allToolbarPanels.itemById('CAMActionPanel')
        if not CAMActionPan:
            raise Exception("Could not access CAM Action Panel")
        
        # Check if command already exists and delete it
        try:
            existing_cmd = ui.commandDefinitions.itemById('citizenPostCommand')
            if existing_cmd:
                existing_cmd.deleteMe()
                time.sleep(0.1)  # Small delay after deletion
        except:
            pass
            
        # Command Definition - use a simple, consistent ID
        selectCitizenPostcmdDef = ui.commandDefinitions.addButtonDefinition('citizenPostCommand','Output to Citizen','Output to Citizen Alkart Wizard','resources')
        if not selectCitizenPostcmdDef:
            raise Exception("Could not create command definition")

        # Add the command to the toolbar
        try:
            CAMActionPan.controls.addCommand(selectCitizenPostcmdDef, '', True)
        except Exception as e:
            raise Exception(f"Failed to add command to toolbar: {str(e)}")
        onCommandCreated = selectCitizenPostCommandCreatedHandler()
        selectCitizenPostcmdDef.commandCreated.add(onCommandCreated)
        handlers.append(onCommandCreated)

        # Add-in loaded successfully

    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        if ui:
            ui.messageBox(f"Initialization Error: {str(e)}\n\nDetails:\n{error_details}")
        else:
            print(f"Initialization Error: {str(e)}")
            print(f"Details: {error_details}")

def endApp(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        # Delete any existing command definitions
        try:
            existing_cmd = ui.commandDefinitions.itemById('citizenPostCommand')
            if existing_cmd:
                existing_cmd.deleteMe()
        except:
            pass

        # Also try to clean up any palette that might exist
        try:
            palette = ui.palettes.itemById('citizenPalette')
            if palette:
                palette.isVisible = False
        except:
            pass

        # Clear handlers list
        global handlers
        handlers.clear()

    except Exception as err:
        # Don't show error messages during cleanup - just log them
        print(f"Cleanup error (this is usually OK): {str(err)}")

# DIALOG FOR MAIN ADD-IN BUTTON - CREATE HTML PALETTE
class selectCitizenPostCommandCreatedHandler(adsk.core.CommandCreatedEventHandler):
    def __init__(self):
        super().__init__()
    
    def notify(self, args):
        ui = None
        try:
            app = adsk.core.Application.get()
            ui = app.userInterface
            
            # Get the HTML file path - use the citizen_selector.html in root folder
            html_path = 'citizen_selector.html'
            full_path = os.path.abspath(os.path.join(os.path.dirname(__file__), html_path))
            if not os.path.exists(full_path):
                html_path = 'resources/samplePage_fixed.html'
                full_path = os.path.abspath(os.path.join(os.path.dirname(__file__), html_path))
                if not os.path.exists(full_path):
                    html_path = 'resources/samplePage.html'
                    full_path = os.path.abspath(os.path.join(os.path.dirname(__file__), html_path))
                    if not os.path.exists(full_path):
                        ui.messageBox(f'HTML file not found: {full_path}', 'Error')
                        return

            # Try different URL formats
            file_url = 'file:///' + full_path.replace('\\', '/')
            alt_url = full_path.replace('\\', '/')
            
            # Check if palette exists, create if it doesn't
            palette = ui.palettes.itemById('citizenPalette')
            if not palette:
                try:
                    # Try with alternative URL format first
                    palette = ui.palettes.add(
                        'citizenPalette',
                        'Citizen Machine Selector',
                        alt_url,
                        True,  # isVisible
                        True,  # showCloseButton
                        True   # isResizable
                    )
                except Exception as e:
                    try:
                        # Try with file:/// format
                        palette = ui.palettes.add(
                            'citizenPalette',
                            'Citizen Machine Selector',
                            file_url,
                            True,  # isVisible
                            True,  # showCloseButton
                            True   # isResizable
                        )
                    except Exception as e2:
                        ui.messageBox(f"Error creating palette: {str(e2)}")
                        return
            else:
                # Palette already exists, just make sure it's visible
                palette.isVisible = True

            palette.dockingState = adsk.core.PaletteDockingStates.PaletteDockStateFloating
            
            # Create and add the HTML handler
            html_handler = HTMLPaletteIncomingHandler()
            
            # Register the event handler
            try:
                palette.incomingFromHTML.add(html_handler)
            except Exception as e:
                ui.messageBox(f"Error registering handler: {str(e)}")
                return
            
            handlers.append(html_handler)
            
            # Show the palette
            palette.isVisible = True
            
            # Position and size the palette
            try:
                palette.dockingState = adsk.core.PaletteDockingStates.PaletteDockStateFloating
                palette.setPosition(100, 100)
                palette.setSize(574, 890)
            except Exception as e:
                pass
                
        except Exception as err:
            if ui:
                ui.messageBox(f"Error creating HTML palette: {str(err)}")

def getPostProperties(form_data=None):
    properties = adsk.core.NamedValues.create()
    
    # Helper functions to get values from form data
    def get_bool(name, default=False):
        if form_data and name in form_data:
            return form_data[name] in ['true', 'on', 'True', True]
        return default
    
    def get_num(name, default=0):
        if form_data and name in form_data:
            try:
                return float(form_data[name])
            except:
                return default
        return default
    
    if selected_post and selected_post.startswith('Miyano'):
        properties.add("miyano_showSequenceNumbers", adsk.core.ValueInput.createByString(str(get_bool("useSequence", False))))
        properties.add("miyano_optionalStop", adsk.core.ValueInput.createByString(str(get_bool("optionalStop", False))))
        properties.add("miyano_useRadius", adsk.core.ValueInput.createByString(str(get_bool("radiusArcs", False))))
        properties.add("miyano_subroutineAll", adsk.core.ValueInput.createByString(str(get_bool("subroutineAll", False))))
        properties.add("miyano_useParametricFeed", adsk.core.ValueInput.createByString(str(get_bool("parametricFeed", False))))
        properties.add("miyano_leaveSpindleRunning", adsk.core.ValueInput.createByString(str(get_bool("leaveSpindles", False))))
        properties.add("miyano_sequenceNumberStart", adsk.core.ValueInput.createByReal(get_num("startSeqNum", 1)))
        properties.add("miyano_sequenceNumberIncrement", adsk.core.ValueInput.createByReal(get_num("seqIncrement", 1)))
        properties.add("miyano_maximumSpindleSpeed", adsk.core.ValueInput.createByReal(get_num("maxSpindleSpeed", 5000)))
        return properties
    
    if selected_post and selected_post.startswith('Citizen'):
        properties.add("showSequenceNumbers", adsk.core.ValueInput.createByString(str(get_bool("useSequence", False))))
        properties.add("optionalStop", adsk.core.ValueInput.createByString(str(get_bool("optionalStop", False))))
        properties.add("useRadius", adsk.core.ValueInput.createByString(str(get_bool("radiusArcs", False))))
        properties.add("subroutineAll", adsk.core.ValueInput.createByString(str(get_bool("subroutineAll", False))))
        properties.add("useG50OnGang", adsk.core.ValueInput.createByString(str(get_bool("g50Gang", False))))
        properties.add("useParametricFeed", adsk.core.ValueInput.createByString(str(get_bool("parametricFeed", False))))
        properties.add("leaveSpindleRunning", adsk.core.ValueInput.createByString(str(get_bool("leaveSpindles", False))))
        properties.add("subSpindlePhaseAngle", adsk.core.ValueInput.createByReal(get_num("subPhaseAngle", 0)))
        properties.add("increaseBAxisStroke", adsk.core.ValueInput.createByString(str(get_bool("increaseBStroke", False))))
        properties.add("sequenceNumberStart", adsk.core.ValueInput.createByReal(get_num("startSeqNum", 1)))
        properties.add("sequenceNumberIncrement", adsk.core.ValueInput.createByReal(get_num("seqIncrement", 1)))
        properties.add("maximumSpindleSpeed", adsk.core.ValueInput.createByReal(get_num("maxSpindleSpeed", 5000)))
    
    return properties

def clearOutputFolder(folder):
    failedFiles = 0
    for fileName in os.listdir(folder):
        file_path = os.path.join(folder, fileName)
        try:
            os.remove(file_path)
        except:
            failedFiles += 1

def postProcess(collection=None, programName='1001', cpsPath=None, outputFolder=None, viewResult=False, form_data=None):
    app = adsk.core.Application.get()
    ui = app.userInterface
    doc = app.activeDocument
    cam = doc.products.itemByProductType('CAMProductType')

    # Set default output folder if not provided
    if not outputFolder:
        outputFolder = get_output_folder()
    
    if not collection:
        collection = cam.allOperations
    if not cpsPath:
        messageBox('No postprocessor selected','Error')

    if cam:
        # specify the NC file output units
        units = adsk.cam.PostOutputUnitOptions.MillimetersOutput
        try:
            app = adsk.core.Application.get()
            ui = app.userInterface
            
            clearOutputFolder(outputFolder)
            app.activeViewport.saveAsImageFile(os.path.join(outputFolder, "placeholder.png"), 400, 400)
            
            # Generate toolpath sketch first (silent)
            postInput = adsk.cam.PostProcessInput.create("opdraw", os.path.join(os.path.dirname(__file__), 'posts', "toolpath sketcher.cps"), outputFolder, units)
            postInput.isOpenInEditor = False
            cam.postProcess(collection, postInput)
            
            # Clean up log files
            logName = programName + '.log'
            logPath = os.path.join(cam.temporaryFolder, programName + '.log')
            for path, subdirs, files in os.walk(cam.temporaryFolder):
                for name in files:
                    if '.log' in name:
                        os.remove(os.path.join(path, name))
            if os.path.exists(logPath):
                os.remove(logPath)
            
            # Generate the actual NC file
            postInput = adsk.cam.PostProcessInput.create(programName, cpsPath, outputFolder, units)
            postInput.postProperties = getPostProperties(form_data)
            postInput.isOpenInEditor = False
            cam.postProcess(collection, postInput)
            time.sleep(3)
            
            try:
                # Check what files were actually generated in the output folder
                output_files = []
                if os.path.exists(outputFolder):
                    output_files = os.listdir(outputFolder)

                # Check for various possible NC file extensions
                nc_file_found = False
                nc_file_path = None
                for ext in ['.nc', '.txt', '.tap', '.cnc']:
                    test_path = os.path.join(outputFolder, programName + ext)
                    if os.path.exists(test_path):
                        nc_file_found = True
                        nc_file_path = test_path
                        break

                if nc_file_found:
                    ui.messageBox('Export successful')
                else:
                    # Show what files were actually created
                    files_info = f"Files in output folder: {output_files}" if output_files else "No files in output folder"
                    ui.messageBox(f'Export failed - no NC file generated.\n\n{files_info}\n\nOutput folder: {outputFolder}')
            except Exception as e:
                ui.messageBox(f'There was an error with post processing: {str(e)}')

        except Exception as err:
            if ui:
                errorText = err.args[0].split('\n')
                fullErrorString = ''
                for i in range(len(errorText)):
                    errorText[i] = errorText[i].strip()
                    if 'Error at' in errorText[i]:
                        errorText[i] = errorText[i].split(':', 1)[1].strip()
                        errorText[i] = "Toolpath with error = " + errorText[i]
                        continue                    
                    if 'Error on' in errorText[i]:
                        # next
                        continue
                    if ':' in errorText[i]:
                        errorText[i] = errorText[i].split(':', 1)[1].strip()
                    fullErrorString += errorText[i] + '\n'
                ui.messageBox(fullErrorString)

class HTMLPaletteIncomingHandler(adsk.core.HTMLEventHandler):
    def __init__(self):
        super().__init__()

    def notify(self, args):
        try:
            app = adsk.core.Application.get()
            ui = app.userInterface
            
            # Debug: Print what we received
            print(f"HTML Handler called with args.data: {getattr(args, 'data', 'None')}")
            print(f"HTML Handler called with args.action: {getattr(args, 'action', 'None')}")
            
            # Initialize variables
            selected_machine = None
            form = {}
            
            # Check if args.data is empty or None
            if not args.data or args.data.strip() == '':
                # Check if data is in args.action instead
                if hasattr(args, 'action') and args.action and args.action.strip():
                    # Use args.action as the data source
                    data_source = args.action
                else:
                    return
            else:
                data_source = args.data
            
            # Handle different message formats
            if data_source.startswith('TRIGGER_PYTHON_PROCESSING:'):
                selected_machine = data_source.replace('TRIGGER_PYTHON_PROCESSING:', '')
                form = {}  # Empty form for simple processing
            elif data_source.startswith('DIRECT_PROCESS:'):
                selected_machine = data_source.replace('DIRECT_PROCESS:', '')
                form = {}  # Empty form for simple processing
            elif data_source.startswith('FORM_READY_FOR_DATA_EXCHANGE'):
                # Request the form data from HTML
                try:
                    palette = ui.palettes.itemById('citizenPalette')
                    if palette:
                        palette.sendInfoToHTML('REQUEST_FORM_DATA', '')
                except Exception as e:
                    pass
                return
            elif data_source.startswith('TEST_BIDIRECTIONAL_COMMUNICATION'):
                # Send a test response back to HTML
                try:
                    palette = ui.palettes.itemById('citizenPalette')
                    if palette:
                        palette.sendInfoToHTML('PYTHON_RESPONSE', 'Test communication successful!')
                except Exception as e:
                    pass
                return
            else:
                # Try to parse as JSON for complex form data
                print(f"Attempting to parse as JSON: {data_source}")
                try:
                    data = json.loads(data_source)
                    print(f"Successfully parsed JSON: {data}")
                    
                    # Check if it's the new format (direct form data)
                    if "selectedImage" in data:
                        selected_machine = data.get("selectedImage")
                        form = data  # The entire data object is the form data
                        print(f"Found selectedImage in data: {selected_machine}")
                    else:
                        # Old format with nested structure
                        selected_machine = data.get("selectedImage")
                        form = data.get("formValues", {})
                        print(f"Using old format, selectedImage: {selected_machine}")
                except json.JSONDecodeError as json_err:
                    print(f"JSON decode error: {json_err}")
                    print(f"Data that failed to parse: {data_source}")
                    return

            if not selected_machine:
                ui.messageBox("No machine selected.")
                return

            # Ensure post lists are populated
            global L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts, posts_fldr, selected_post, output_fldr
            
            # Always reinitialize posts_fldr to be safe
            posts_fldr = os.path.join(os.path.dirname(__file__), 'posts')
            
            # Check if posts folder exists
            if not os.path.exists(posts_fldr):
                ui.messageBox(f"Posts folder not found: {posts_fldr}")
                return
            
            # Always repopulate post lists to ensure they're current
            L1_posts.clear()
            L2_posts.clear()
            L3_posts.clear()
            L320_posts.clear()
            Miyano_posts.clear()
            other_posts.clear()
            
            try:
                file_list = [f for f in listdir(posts_fldr) if isfile(join(posts_fldr, f))]
                
                for f in file_list:
                    if not f.endswith('.cps') or f.lower() in ['common700.cps', 'toolpath sketcher.cps', 'common800.cps']:
                        continue
                    if f.startswith('Citizen L1'):
                        L1_posts.append(f)
                    elif f.startswith('Citizen L2'):
                        L2_posts.append(f)
                    elif f.startswith('Citizen L3'):
                        L3_posts.append(f)
                    elif f.startswith('Citizen L320'):
                        L320_posts.append(f)
                    elif f.startswith('Miyano'):
                        Miyano_posts.append(f)
                    else:
                        other_posts.append(f)
            except Exception as e:
                ui.messageBox(f"Error reading posts folder: {str(e)}")
                return

            cps_file = find_matching_post(selected_machine)
            if not cps_file:
                ui.messageBox(f"No post processor found for: {selected_machine}")
                return

            selected_post = cps_file

            # Initialize posts_fldr and output_fldr if not set
            if not posts_fldr:
                posts_fldr = os.path.join(os.path.dirname(__file__), 'posts')
            if not output_fldr:
                output_fldr = get_output_folder()
                if not os.path.exists(output_fldr):
                    os.makedirs(output_fldr, exist_ok=True)
            
            # Paths are now set correctly

            doc = app.activeDocument
            cam = doc.products.itemByProductType('CAMProductType')
            operationCollection = adsk.core.ObjectCollection.create()
            
            # Check for selected setups first
            for setup in cam.setups:
                if setup.isSelected:
                    operationCollection.add(setup)
            
            # If no setups are selected, check for selected operations
            if operationCollection.count == 0:
                for setup in cam.setups:
                    for operation in setup.operations:
                        if operation.isSelected:
                            operationCollection.add(operation)
            
            # If still no selections, check for selected toolpaths
            if operationCollection.count == 0:
                for setup in cam.setups:
                    for operation in setup.operations:
                        # Check if operation has toolpaths attribute
                        if hasattr(operation, 'toolpaths'):
                            for toolpath in operation.toolpaths:
                                if toolpath.isSelected:
                                    operationCollection.add(toolpath)

            if operationCollection.count == 0:
                ui.messageBox("Please select a setup, operation, or toolpath in the CAM workspace before submitting.")
                return

            if selected_post:
                postProcess(
                    collection=operationCollection,
                    cpsPath=os.path.join(posts_fldr, selected_post),
                    outputFolder=output_fldr,
                    viewResult=True,
                    form_data=form
                )
                palette = ui.palettes.itemById('citizenPalette')
                if palette:
                    palette.isVisible = False
            else:
                ui.messageBox("Post processor not selected.")
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            print(f"HTML Handler Error: {str(e)}")
            print(f"Error details: {error_details}")
            ui.messageBox(f"HTML Handler Error:\n{str(e)}\n\nDetails:\n{error_details}")

def find_matching_post(machine_name):
    global L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts
    all_posts = L1_posts + L2_posts + L3_posts + L320_posts + Miyano_posts + other_posts
    for f in all_posts:
        simplified = f.replace("Citizen ", "").replace("Miyano ", "").replace(".cps", "")
        if simplified.lower() == machine_name.lower():
            return f
    return None
