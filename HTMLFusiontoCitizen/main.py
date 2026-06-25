import traceback
import adsk.core, adsk.fusion, adsk.cam, os, json, urllib.request # type: ignore
from datetime import datetime, timedelta
from os import listdir
from os.path import isfile, join
import sys
import time
import tempfile
import ctypes

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
palette_html_handler_registered = False
last_submit_payload = None
last_submit_time = 0.0
post_request_in_progress = False
last_post_request_time = 0.0
last_export_message_time = 0.0
addon_initialized = False
startup_guard_pid = None
startup_invocation_count = 0
MACHINE_SELECTION_FILE = 'machine_visibility.json'
MACHINE_DEFINITIONS_FILE = 'machines_config.json'

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

def center_palette_on_screen(palette, width=574, height=890):
    try:
        user32 = ctypes.windll.user32
        screen_width = user32.GetSystemMetrics(0)
        screen_height = user32.GetSystemMetrics(1)
        x = max(0, int((screen_width - width) / 2))
        y = max(0, int((screen_height - height) / 2))
        palette.setPosition(x, y)
    except Exception as err:
        print(f"Palette centering skipped: {str(err)}")

def get_resources_path():
    return os.path.join(os.path.dirname(__file__), 'resources')

def get_machines_file_path():
    resources_path = get_resources_path()
    resources_machines = os.path.join(resources_path, 'machines.txt')
    root_machines = os.path.join(os.path.dirname(__file__), 'machines.txt')
    if os.path.exists(resources_machines):
        return resources_machines
    return root_machines

def get_machine_definitions_file_path():
    return os.path.join(get_resources_path(), MACHINE_DEFINITIONS_FILE)

def sanitize_machine_definitions(raw_machines):
    sanitized = []
    seen_values = set()

    if not isinstance(raw_machines, list):
        return sanitized

    for entry in raw_machines:
        if not isinstance(entry, dict):
            continue

        series = str(entry.get('series', '')).strip() or 'General'
        label = str(entry.get('label', '')).strip()
        value = str(entry.get('value', '')).strip()
        image_path = str(entry.get('imagePath', '')).strip()

        if not label and value:
            label = value
        if not value and label:
            value = label
        if not label or not value:
            continue

        dedupe_key = value.lower()
        if dedupe_key in seen_values:
            continue
        seen_values.add(dedupe_key)

        sanitized.append({
            'series': series,
            'label': label,
            'value': value,
            'imagePath': resolve_machine_image_path(image_path)
        })

    return sanitized

def load_machine_definitions_from_json():
    definitions_path = get_machine_definitions_file_path()
    if not os.path.exists(definitions_path):
        return None

    try:
        with open(definitions_path, 'r', encoding='utf-8') as definitions_file:
            payload = json.load(definitions_file)
            if isinstance(payload, dict):
                raw_machines = payload.get('machines', [])
            else:
                raw_machines = payload
            return sanitize_machine_definitions(raw_machines)
    except Exception as err:
        print(f"Failed to load machine definitions JSON: {str(err)}")
        return None

def save_machine_definitions(raw_machines):
    sanitized = sanitize_machine_definitions(raw_machines)

    try:
        definitions_path = get_machine_definitions_file_path()
        with open(definitions_path, 'w', encoding='utf-8') as definitions_file:
            json.dump({'machines': sanitized}, definitions_file, indent=2)
    except Exception as err:
        print(f"Failed to save machine definitions JSON: {str(err)}")

    return sanitized

def resolve_machine_image_path(image_ref):
    if not image_ref:
        return ''

    image_ref = str(image_ref).strip()
    if not image_ref:
        return ''

    # Keep absolute paths untouched.
    if os.path.isabs(image_ref):
        return image_ref

    resources_path = get_resources_path()
    image_ref_forward = image_ref.replace('\\', '/').lstrip('./')
    file_name = os.path.basename(image_ref_forward)

    candidates = [
        os.path.join(resources_path, image_ref_forward.replace('/', os.sep)),
        os.path.join(resources_path, 'Machines', file_name),
        os.path.join(resources_path, 'machines', file_name),
    ]

    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate

    # Fallback to the likely location even if the file isn't present yet.
    return os.path.join(resources_path, 'Machines', file_name)

def read_machine_definitions():
    json_machines = load_machine_definitions_from_json()
    if json_machines is not None:
        return json_machines

    machines_path = get_machines_file_path()
    machines = []
    last_series = 'General'

    if not os.path.exists(machines_path):
        return machines

    try:
        with open(machines_path, 'r', encoding='utf-8') as machine_file:
            for raw_line in machine_file:
                line = raw_line.strip()
                if not line or line.startswith('#'):
                    continue

                parts = [part.strip() for part in line.split('|') if part.strip()]
                if len(parts) >= 3:
                    series_name, label, image_ref = parts[0], parts[1], parts[2]
                    value = parts[3] if len(parts) >= 4 else label
                    last_series = series_name
                elif len(parts) == 2:
                    # Allow shorthand lines that inherit the previous series.
                    label, image_ref = parts[0], parts[1]
                    value = label
                    series_name = last_series

                    # If the shorthand row appears after a comment separator,
                    # infer a better series from the machine label.
                    if label.startswith('L1'):
                        series_name = 'L10Series'
                    elif label.startswith('L2') or label.startswith('L3'):
                        series_name = 'L20Series'
                    elif label.startswith('M') and ('MYY' not in label):
                        series_name = 'MSeries'
                else:
                    continue

                machines.append({
                    'series': series_name,
                    'label': label,
                    'value': value,
                    'imagePath': resolve_machine_image_path(image_ref)
                })
    except Exception as err:
        print(f"Failed to read machine definitions: {str(err)}")

    return machines

def get_machine_selection_file_path():
    return os.path.join(get_resources_path(), MACHINE_SELECTION_FILE)

def list_machine_image_files():
    resources_path = get_resources_path()
    image_dirs = [
        os.path.join(resources_path, 'Machines'),
        os.path.join(resources_path, 'machines')
    ]
    valid_exts = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'}
    files = []
    seen = set()

    for image_dir in image_dirs:
        if not os.path.isdir(image_dir):
            continue
        try:
            for name in os.listdir(image_dir):
                file_path = os.path.join(image_dir, name)
                if not os.path.isfile(file_path):
                    continue
                _, ext = os.path.splitext(name)
                if ext.lower() not in valid_exts:
                    continue
                key = name.lower()
                if key in seen:
                    continue
                seen.add(key)
                files.append(name)
        except Exception:
            pass

    files.sort(key=lambda v: v.lower())
    return files

def load_visible_machine_values(all_machines):
    machine_values = [machine.get('value') for machine in all_machines if machine.get('value')]
    selection_path = get_machine_selection_file_path()

    if not os.path.exists(selection_path):
        return machine_values

    try:
        with open(selection_path, 'r', encoding='utf-8') as selection_file:
            payload = json.load(selection_file)
            configured = payload.get('visibleMachines', []) if isinstance(payload, dict) else []
    except Exception as err:
        print(f"Failed to read machine visibility settings: {str(err)}")
        return machine_values

    valid_values = set(machine_values)
    return [value for value in configured if value in valid_values]

def save_visible_machine_values(visible_values, all_machines):
    valid_ordered_values = [machine.get('value') for machine in all_machines if machine.get('value')]
    valid_value_set = set(valid_ordered_values)

    requested = visible_values if isinstance(visible_values, list) else []
    sanitized = []
    for value in valid_ordered_values:
        if value in requested and value in valid_value_set:
            sanitized.append(value)

    try:
        selection_path = get_machine_selection_file_path()
        with open(selection_path, 'w', encoding='utf-8') as selection_file:
            json.dump({'visibleMachines': sanitized}, selection_file, indent=2)
    except Exception as err:
        print(f"Failed to save machine visibility settings: {str(err)}")

    return sanitized

def get_machine_config_payload():
    all_machines = read_machine_definitions()
    visible_values = load_visible_machine_values(all_machines)
    return {
        'machines': all_machines,
        'visibleMachines': visible_values,
        'imageFiles': list_machine_image_files()
    }

def send_machine_config_to_palette(ui):
    try:
        palette = ui.palettes.itemById('citizenPalette')
        if not palette:
            return
        payload = json.dumps(get_machine_config_payload())
        palette.sendInfoToHTML('MACHINE_CONFIG', payload)
    except Exception as err:
        print(f"Failed to send machine configuration to palette: {str(err)}")

def should_skip_duplicate_startup():
    global startup_guard_pid
    pid = os.getpid()
    lock_path = os.path.join(tempfile.gettempdir(), 'citizen_addin_startup.lock')

    # In-process guard.
    if startup_guard_pid == pid:
        return True

    # Cross-invocation guard for the same Fusion process.
    try:
        if os.path.exists(lock_path):
            with open(lock_path, 'r', encoding='ascii') as f:
                lock_pid = f.read().strip()
            if lock_pid == str(pid):
                startup_guard_pid = pid
                return True
        with open(lock_path, 'w', encoding='ascii') as f:
            f.write(str(pid))
    except:
        # If locking fails, continue instead of blocking startup.
        pass

    startup_guard_pid = pid
    return False

def remove_toolbar_control(ui, control_id):
    try:
        for panel in ui.allToolbarPanels:
            try:
                existing_control = panel.controls.itemById(control_id)
                if existing_control:
                    existing_control.deleteMe()
            except:
                pass
    except:
        pass

def remove_citizen_toolbar_controls(ui):
    def should_remove_control(control):
        cid = ''
        cmd_id = ''
        cmd_name = ''
        try:
            cid = str(control.id)
        except:
            pass
        try:
            cmd_def = control.commandDefinition
            if cmd_def:
                cmd_id = str(cmd_def.id)
                try:
                    cmd_name = str(cmd_def.name)
                except:
                    pass
        except:
            pass

        return (
            cid in ['selectCitizenPostButtonControl', 'citizenPostProcessorV2Control']
            or cid.startswith('selectCitizenPostButtonControl_')
            or cmd_id in ['selectCitizenPost', 'citizenPostCommand', 'citizenPostProcessorV2']
            or cmd_name == 'Output to Citizen'
        )

    def remove_from_controls(controls):
        ids_to_remove = []
        nested_collections = []

        for control in controls:
            try:
                if should_remove_control(control):
                    ids_to_remove.append(str(control.id))
            except:
                pass

            # Recurse into dropdown-style controls.
            try:
                if hasattr(control, 'controls') and control.controls:
                    nested_collections.append(control.controls)
            except:
                pass

        for cid in ids_to_remove:
            try:
                ctrl = controls.itemById(cid)
                if ctrl:
                    ctrl.deleteMe()
            except:
                pass

        for nested in nested_collections:
            try:
                remove_from_controls(nested)
            except:
                pass

    try:
        for panel in ui.allToolbarPanels:
            try:
                remove_from_controls(panel.controls)
            except:
                pass
    except:
        pass

def remove_citizen_command_definitions(ui):
    try:
        cmd_defs = ui.commandDefinitions
        if not cmd_defs:
            return

        # Remove known legacy/current/new IDs first.
        for cmd_id in ['selectCitizenPost', 'citizenPostCommand', 'citizenPostProcessorV2']:
            try:
                cmd_def = cmd_defs.itemById(cmd_id)
                if cmd_def:
                    cmd_def.deleteMe()
            except:
                pass

        # Also remove any lingering definitions by display name.
        ids_to_remove = []
        try:
            for cmd_def in cmd_defs:
                try:
                    if str(cmd_def.name) == 'Output to Citizen':
                        ids_to_remove.append(str(cmd_def.id))
                except:
                    pass
        except:
            pass

        for cmd_id in ids_to_remove:
            try:
                cmd_def = cmd_defs.itemById(cmd_id)
                if cmd_def:
                    cmd_def.deleteMe()
            except:
                pass
    except:
        pass

def has_citizen_button_or_command(ui):
    try:
        cmd_defs = ui.commandDefinitions
        if cmd_defs and cmd_defs.itemById('selectCitizenPost'):
            return True
    except:
        pass

    try:
        for panel in ui.allToolbarPanels:
            try:
                for control in panel.controls:
                    try:
                        cmd_def = control.commandDefinition
                        if cmd_def and str(cmd_def.id) in ['selectCitizenPost', 'citizenPostCommand']:
                            return True
                        if cmd_def and str(cmd_def.name) == 'Output to Citizen':
                            return True
                    except:
                        pass
            except:
                pass
    except:
        pass

    return False

def show_citizen_palette(ui):
    global palette_html_handler_registered
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

    file_url = 'file:///' + full_path.replace('\\', '/')
    alt_url = full_path.replace('\\', '/')

    palette = ui.palettes.itemById('citizenPalette')
    if not palette:
        try:
            palette = ui.palettes.add(
                'citizenPalette',
                'Citizen Machine Selector',
                alt_url,
                True,
                True,
                True
            )
        except Exception:
            try:
                palette = ui.palettes.add(
                    'citizenPalette',
                    'Citizen Machine Selector',
                    file_url,
                    True,
                    True,
                    True
                )
            except Exception as e2:
                ui.messageBox(f"Error creating palette: {str(e2)}")
                return
    else:
        palette.isVisible = True

    palette.dockingState = adsk.core.PaletteDockingStates.PaletteDockStateFloating

    # Register HTML handler only once per add-in session.
    if not palette_html_handler_registered:
        html_handler = HTMLPaletteIncomingHandler()
        try:
            palette.incomingFromHTML.add(html_handler)
        except Exception as e:
            ui.messageBox(f"Error registering handler: {str(e)}")
            return

        handlers.append(html_handler)
        palette_html_handler_registered = True

    try:
        palette.dockingState = adsk.core.PaletteDockingStates.PaletteDockStateFloating
        palette.setSize(574, 890)
        center_palette_on_screen(palette, 574, 890)
    except Exception:
        pass

    palette.isVisible = True
    send_machine_config_to_palette(ui)

def startApp(context):
    global posts_fldr, output_fldr, addon_initialized, palette_html_handler_registered, startup_invocation_count

    startup_invocation_count += 1
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

        # Fusion may invoke startup multiple times in quick succession when
        # run-on-startup is enabled. Allow only the first invocation.
        if should_skip_duplicate_startup():
            print(f"Citizen: Skipped duplicate startup invocation #{startup_invocation_count}")
            return

        # Always run cleanup/rebuild on startup to force UI convergence to one icon.
        addon_initialized = True
        
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
        
        # Always clean up old controls/definitions before creating the single fresh button.
        try:
            remove_citizen_toolbar_controls(ui)
            remove_citizen_command_definitions(ui)
            handlers.clear()
            palette_html_handler_registered = False
        except:
            pass

        # Small delay to ensure cleanup is complete.
        time.sleep(0.2)

        # Remove previously created duplicated controls from earlier versions.
        remove_citizen_toolbar_controls(ui)
        remove_citizen_command_definitions(ui)

        cmdDefs = ui.commandDefinitions
        if not cmdDefs:
            raise Exception("Could not access command definitions")

        selectCitizenPostcmdDef = cmdDefs.addButtonDefinition(
            'citizenPostProcessorV2',
            'Output to Citizen',
            'Output to Citizen Alkart Wizard',
            get_resources_path()
        )

        onCommandCreated = selectCitizenPostCommandCreatedHandler()
        selectCitizenPostcmdDef.commandCreated.add(onCommandCreated)
        handlers.append(onCommandCreated)

        try:
            button_panel = ui.allToolbarPanels.itemById('CAMActionPanel')
            if not button_panel:
                button_panel = ui.allToolbarPanels.itemById('CAMAddinsPanel')

            if button_panel:
                control = button_panel.controls.itemById('citizenPostProcessorV2Control')
                if not control:
                    control = button_panel.controls.addCommand(
                        selectCitizenPostcmdDef,
                        'citizenPostProcessorV2Control',
                        True
                    )
                if control:
                    control.isVisible = True
                    control.isPromoted = False
                    try:
                        control.isPromotedByDefault = False
                    except:
                        pass
            else:
                ui.messageBox(
                    "Citizen button could not be added: Manufacturing panel not found.",
                    "Citizen Button Placement"
                )
        except Exception as e:
            print(f"Toolbar button not added: {str(e)}")

        addon_initialized = True

        # Add-in loaded successfully

    except Exception as e:
        addon_initialized = False
        import traceback
        error_details = traceback.format_exc()
        if ui:
            ui.messageBox(f"Initialization Error: {str(e)}\n\nDetails:\n{error_details}")
        else:
            print(f"Initialization Error: {str(e)}")
            print(f"Details: {error_details}")

def endApp(context):
    global palette_html_handler_registered, last_submit_payload, last_submit_time, post_request_in_progress, last_post_request_time, last_export_message_time, addon_initialized, startup_guard_pid, startup_invocation_count
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        # Also try to clean up any palette that might exist
        try:
            palette = ui.palettes.itemById('citizenPalette')
            if palette:
                palette.isVisible = False
        except:
            pass

        # Also remove the toolbar control so startup can re-add it cleanly
        remove_citizen_toolbar_controls(ui)
        remove_citizen_command_definitions(ui)

        # Clear handlers list
        global handlers
        handlers.clear()
        palette_html_handler_registered = False
        last_submit_payload = None
        last_submit_time = 0.0
        post_request_in_progress = False
        last_post_request_time = 0.0
        last_export_message_time = 0.0
        addon_initialized = False
        startup_guard_pid = None
        startup_invocation_count = 0

        # Clear startup lock for this process.
        try:
            lock_path = os.path.join(tempfile.gettempdir(), 'citizen_addin_startup.lock')
            if os.path.exists(lock_path):
                with open(lock_path, 'r', encoding='ascii') as f:
                    lock_pid = f.read().strip()
                if lock_pid == str(os.getpid()):
                    os.remove(lock_path)
        except:
            pass

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
            show_citizen_palette(ui)
                
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
    global last_export_message_time
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
            time.sleep(1)
            
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
                    now = time.time()
                    if (now - last_export_message_time) > 12:
                        ui.messageBox('Export completed')
                        last_export_message_time = now
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
            global last_submit_payload, last_submit_time, post_request_in_progress, last_post_request_time
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

            # Ignore immediate duplicate post submits from repeated HTML events/handlers.
            now = time.time()
            payload_key = data_source.strip() if data_source else ''
            is_control_message = payload_key.startswith('{') and ('"action"' in payload_key)
            if (not is_control_message) and payload_key and payload_key == last_submit_payload and (now - last_submit_time) < 8:
                return
            if payload_key and (not is_control_message):
                last_submit_payload = payload_key
                last_submit_time = now

            # Some Fusion builds can pass control actions directly in args.action.
            if data_source in ['requestMachineConfig', 'refreshMachineConfig']:
                send_machine_config_to_palette(ui)
                return
            
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
                    
                    action = data.get("action") if isinstance(data, dict) else None

                    if action == 'requestMachineConfig':
                        send_machine_config_to_palette(ui)
                        return
                    elif action == 'saveMachineSelection':
                        all_machines = read_machine_definitions()
                        save_visible_machine_values(data.get('visibleMachines', []), all_machines)
                        send_machine_config_to_palette(ui)
                        return
                    elif action == 'saveMachineDefinitions':
                        all_machines = save_machine_definitions(data.get('machines', []))
                        save_visible_machine_values(data.get('visibleMachines', []), all_machines)
                        send_machine_config_to_palette(ui)
                        return
                    elif action == 'refreshMachineConfig':
                        send_machine_config_to_palette(ui)
                        return

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

            # Ignore non-post UI messages that don't include a machine selection.
            # The HTML form already validates selection on actual Post clicks.
            if not selected_machine:
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
                now = time.time()
                # Hard guard against duplicate submit events.
                if post_request_in_progress:
                    return
                if (now - last_post_request_time) < 12:
                    return

                post_request_in_progress = True
                last_post_request_time = now
                try:
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
                finally:
                    post_request_in_progress = False
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
