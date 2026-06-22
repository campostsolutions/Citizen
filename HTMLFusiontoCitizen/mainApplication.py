import traceback
from xml.dom import ValidationErr
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

def getCAM():
    app = adsk.core.Application.get()
    doc = app.activeDocument
    cam = doc.products.itemByProductType('CAMProductType')
    return cam

def downloadPostList():
    app = adsk.core.Application.get()
    ui  = app.userInterface
    onlinePostLocation = "https://cam.autodesk.com/posts/posts/posts-website.json"
    postsFolder = os.path.join(os.getenv('APPDATA'), 'CitizenPosts')
    if not os.path.exists(postsFolder):
        os.mkdir(postsFolder)
    localPostJsonPath = os.path.join(postsFolder, 'posts.json')
    if os.path.exists(localPostJsonPath):
        t = datetime.utcfromtimestamp(os.path.getmtime(localPostJsonPath))
        now = datetime.now()
        if (now-t).days > 3:
            downloadFile(onlinePostLocation, localPostJsonPath)
            tf = open(localPostJsonPath)
            jsonContents = json.load(tf)
            tf.close()
            postsToDownload = []
            for i in jsonContents:
                if i['vendor'].upper() == 'CITIZEN':
                    postsToDownload.append(i['filename'] + '.cps')
            for post in postsToDownload:
                downloadFile("https://cam.autodesk.com/posts/posts/" + post, os.path.join(postsFolder, post))

def readFile(file):
    tf = open(file, 'r')
    contents = tf.read()
    tf.close()
    return contents

def downloadFile(file, path):
    try:
        r = urllib.request.urlretrieve(file, path)
    except:
        messageBox('Failed to download file')

def messageBox(text: str, title: object = None) -> object:
    if not title:
        title = 'Message'
    app =adsk.core.Application.get()
    ui = app.userInterface
    ui.messageBox(text, title)
    return text

def startApp(context):
    
    

    ui = None
    try:
        app = adsk.core.Application.get()
        ui  = app.userInterface
        if sys.platform == 'darwin':
            messageBox('Unfortunately the Citizen addin only works on Windows')
            return
        endApp(context)

        cmdDefs = ui.commandDefinitions
        citizenAddin = cmdDefs.itemById('selectCitizenPost')
        if citizenAddin:
            citizenAddin.deleteMe()
        # Command Definition
        selectCitizenPostcmdDef = ui.commandDefinitions.addButtonDefinition('selectCitizenPost','Output to Citizen','Output to Citizen Alkart Wizard','resources')

        #Select Actions panel in CAM workspace as location for button
        CAMActionPan = ui.allToolbarPanels.itemById('CAMActionPanel')

        CAMActionPan = ui.allToolbarPanels.itemById('CAMActionPanel')
        CAMActionPan.controls.addCommand(selectCitizenPostcmdDef, 'selectCitizenPostButtonControl', True)
        onCommandCreated = selectCitizenPostCommandCreatedHandler()
        selectCitizenPostcmdDef.commandCreated.add(onCommandCreated)
        handlers.append(onCommandCreated)


    except ValidationErr as err:
        if ui:
            ui.messageBox(str(err))

    html_path = os.path.join(os.path.dirname(__file__), 'resources', 'samplePage.html')
    palette = ui.palettes.itemById('citizenPalette')
    if not palette:
        palette = ui.palettes.add(
        'citizenPalette',
        'Citizen Machine Selector',
        html_path,
        True,  # Show as a dialog
        True,  # Is resizable
        True,  # Show close button
        600,   # Width
        700    # Height
    )

    palette.dockingState = adsk.core.PaletteDockingStates.PaletteDockStateFloating
    palette.isVisible = True
    palette.incomingFromHTML.add(HTMLPaletteIncomingHandler())
    handlers.append(HTMLPaletteIncomingHandler())

def parseToBool(string):
    r = {'True': True, 'False': False}
    return r.get(string, string)

# DIALOG FOR MAIN ADD-IN BUTTON - CREATE MAIN FORM
class selectCitizenPostCommandCreatedHandler(adsk.core.CommandCreatedEventHandler):
    def __init__(self):
        super().__init__()
    def notify(self, args):
        try:
            global posts_fldr, output_fldr, select_post_dropdown, select_units
            global bool_showSequenceNumbers, bool_optionalStop, bool_useRadius, bool_parametricFeed, bool_spindleRunning, bool_useG50OnGang, bool_increaseBAxisStroke
            global spinner_sequenceNumberStart, spinner_sequenceNumberInc, spinner_maxSpindle, spinner_subSpindlePhaseAngle, bool_subroutineAll
            global citizenGroup, miyanoGroup
            global bool_miyano_showSequenceNumbers, bool_miyano_optionalStop, bool_miyano_useRadius, bool_miyano_parametricFeed, bool_miyano_spindleRunning
            global spinner_miyano_sequenceNumberStart, spinner_miyano_sequenceNumberInc, spinner_miyano_maxSpindle, bool_miyano_subroutineAll
            app = adsk.core.Application.get()
            ui  = app.userInterface
            cmd = args.command
            inputs = cmd.commandInputs
            cmd.okButtonText = 'Post Process'
            cmd.setDialogMinimumSize(475,500)
            #set some default values
            my_profile = os.environ['USERPROFILE']
            install_fldr = os.path.join(my_profile, 'AppData', 'Local', 'FusionToCitizen')
            posts_fldr = os.path.join(os.path.dirname(__file__), 'posts')

            output_fldr = install_fldr

            if not os.path.exists(output_fldr):
                os.mkdir(output_fldr)

            # GROUP TO SHOW FOLDER LOCATIONS AND POST SELECTOR DROPDOWN
            groupCmdInput1 = inputs.addGroupCommandInput('postSelection', 'Post Processor Selection')
            groupChildInputs1 = groupCmdInput1.children

            # dropdown showing posts in selected directory - populated by on change
            # Correctly assign select_post_dropdown as the DropDownCommandInput
            select_post_dropdown = groupChildInputs1.addDropDownCommandInput('select_post', 'Select Post', adsk.core.DropDownStyles.TextListDropDownStyle)

            # Pass both the listItems and the command input itself to populate_posts_dropdown
            populate_posts_dropdown(posts_fldr, select_post_dropdown.listItems, select_post_dropdown)

            select_units = groupChildInputs1.addRadioButtonGroupCommandInput('unit_selection', 'Output units')
            unit_items  = select_units.listItems
            unit_items.add('MM', True)
            unit_items.add('IN', False)
            select_units.isFullWidth = True

            # GROUP TO SHOW POST PROPERTIES
# CITIZEN POST PROPERTIES
            citizenGroup = inputs.addGroupCommandInput('citizen_props', 'Citizen Post Properties')
            citizenGroup.isExpanded = True
            citizenGroup.isEnabledCheckBoxDisplayed = False
            citizenInputs = citizenGroup.children

# MIYANO POST PROPERTIES
            miyanoGroup = inputs.addGroupCommandInput('miyano_props', 'Miyano Post Properties')
            miyanoGroup.isExpanded = True
            miyanoGroup.isEnabledCheckBoxDisplayed = False
            miyanoInputs = miyanoGroup.children

            # old line removed

            # storing of params
            doc = app.activeDocument
            attr = doc.attributes
            showSequenceNumbers = parseToBool(attr.itemByName('citizen', 'showSequenceNumbers').value) if attr.itemByName('citizen', 'showSequenceNumbers') is not None else False
            subroutineAll = parseToBool(attr.itemByName('citizen', 'subroutineAll').value) if attr.itemByName('citizen', 'subroutineAll') is not None else False
            optionalStop = parseToBool(attr.itemByName('citizen', 'optionalStop').value) if attr.itemByName('citizen', 'optionalStop') is not None else True # Default to True
            useRadius = parseToBool(attr.itemByName('citizen', 'useRadius').value) if attr.itemByName('citizen', 'useRadius') is not None else True
            parametricFeed = parseToBool(attr.itemByName('citizen', 'useParametricFeed').value) if attr.itemByName('citizen', 'useParametricFeed') is not None else False
            spindleRunning = parseToBool(attr.itemByName('citizen', 'leaveSpindleRunning').value) if attr.itemByName('citizen', 'leaveSpindleRunning') is not None else True
            useG50OnGang = parseToBool(attr.itemByName('citizen', 'useG50OnGang').value) if attr.itemByName('citizen', 'useG50OnGang') is not None else False
            subSpindlePhaseAngle = float(attr.itemByName('citizen', 'subSpindlePhaseAngle').value) if attr.itemByName('citizen', 'subSpindlePhaseAngle') is not None else 0
            sequenceNumberStart = int(attr.itemByName('citizen', 'sequenceNumberStart').value) if attr.itemByName('citizen', 'sequenceNumberStart') is not None else 1
            sequenceNumberInc = int(attr.itemByName('citizen', 'sequenceNumberIncrement').value) if attr.itemByName('citizen', 'sequenceNumberIncrement') is not None else 1
            maxSpindle = int(attr.itemByName('citizen', 'maximumSpindleSpeed').value) if attr.itemByName('citizen', 'maximumSpindleSpeed') is not None else 5000
            increaseBAxisStroke = parseToBool(attr.itemByName('citizen', 'increaseBAxisStroke').value) if attr.itemByName('citizen', 'increaseBAxisStroke') is not None else False

            bool_showSequenceNumbers = citizenInputs.addBoolValueInput('showSequenceNumbers', 'Use sequence numbers', True, '', showSequenceNumbers)
            bool_subroutineAll = citizenInputs.addBoolValueInput('subroutineAll', 'Output Code as Sub Programs', True, '', subroutineAll)
            bool_optionalStop = citizenInputs.addBoolValueInput('optionalStop', 'Optional stop', True, '', optionalStop)
            bool_useRadius = citizenInputs.addBoolValueInput('useRadius', 'Radius Arcs', True, '', useRadius)
            bool_parametricFeed = citizenInputs.addBoolValueInput('useParametricFeed', 'Parametric Feed', True, '', parametricFeed)
            bool_spindleRunning = citizenInputs.addBoolValueInput('leaveSpindleRunning', 'Leave Spindles Running', True, '', spindleRunning)
            bool_useG50OnGang = citizenInputs.addBoolValueInput('useG50OnGang', 'G50 on Gang Driven', True, '', useG50OnGang)
            bool_increaseBAxisStroke = citizenInputs.addBoolValueInput('increaseBAxisStroke', 'Increase B-axis stroke', True, '', increaseBAxisStroke)
            spinner_subSpindlePhaseAngle = citizenInputs.addFloatSpinnerCommandInput('subSpindlePhaseAngle', 'Sub Spindle Phase Angle','' , 0, 360, 1 , subSpindlePhaseAngle)
            spinner_sequenceNumberStart = citizenInputs.addIntegerSpinnerCommandInput('sequenceNumberStart', 'Start sequence number', 0 , 20000, 1, sequenceNumberStart)
            spinner_sequenceNumberInc = citizenInputs.addIntegerSpinnerCommandInput('sequenceNumberIncrement', 'Sequence number increment', 0 , 20000, 1, sequenceNumberInc)
            spinner_maxSpindle = citizenInputs.addIntegerSpinnerCommandInput('maximumSpindleSpeed', 'Max spindle speed', 0 , 20000, 1, maxSpindle)

            onInputChanged = formUpdatedEventHandler()
            cmd.inputChanged.add(onInputChanged)
            
            bool_miyano_showSequenceNumbers = miyanoInputs.addBoolValueInput('showSequenceNumbers', 'Use sequence numbers', True, '', showSequenceNumbers)
            bool_miyano_subroutineAll = miyanoInputs.addBoolValueInput('subroutineAll', 'Output Code as Sub Programs', True, '', subroutineAll)
            bool_miyano_optionalStop = miyanoInputs.addBoolValueInput('optionalStop', 'Optional stop', True, '', optionalStop)
            bool_miyano_useRadius = miyanoInputs.addBoolValueInput('useRadius', 'Radius Arcs', True, '', useRadius)
            bool_miyano_parametricFeed = miyanoInputs.addBoolValueInput('useParametricFeed', 'Parametric Feed', True, '', parametricFeed)
            bool_miyano_spindleRunning = miyanoInputs.addBoolValueInput('leaveSpindleRunning', 'Leave Spindles Running', True, '', spindleRunning)
            spinner_miyano_sequenceNumberStart = miyanoInputs.addIntegerSpinnerCommandInput('sequenceNumberStart', 'Start sequence number', 0 , 20000, 1, sequenceNumberStart)
            spinner_miyano_sequenceNumberInc = miyanoInputs.addIntegerSpinnerCommandInput('sequenceNumberIncrement', 'Sequence number increment', 0 , 20000, 1, sequenceNumberInc)
            spinner_miyano_maxSpindle = miyanoInputs.addIntegerSpinnerCommandInput('maximumSpindleSpeed', 'Max spindle speed', 0 , 20000, 1, maxSpindle)
            miyanoGroup.isVisible = False  # Start hidden


            handlers.append(onInputChanged)

            # Connect up to command executed event
            onExecute = selectCitizenPostExecutedEventHandler()
            cmd.execute.add(onExecute)
            handlers.append(onExecute)

        except Exception as err:
            if ui:
                ui.messageBox(err.args[0])

# Modified populate_posts_dropdown to accept the ListItems object AND the DropDownCommandInput itself
def populate_posts_dropdown(posts_fldr, dropdown_listItems, dropdown_command_input):
    # Empty the drop down list first
    dropdown_listItems.clear()
    file_list = [f for f in listdir(posts_fldr) if isfile(join(posts_fldr, f))]

    # Categorize files (global so formUpdatedEventHandler can access them)
    global L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts
    L1_posts = []
    L2_posts = []
    L3_posts = []
    L320_posts = []
    Miyano_posts = []
    other_posts = []

    for f in file_list:
        if not f.endswith('.cps') or f.lower() in ['common700.cps', 'toolpath sketcher.cps', 'common800.cps']:
            continue
        if f.startswith('Citizen L1'):
            L1_posts.append(f)
        elif f.startswith('Citizen L2'):
            L2_posts.append(f)
        elif f.startswith('Citizen L32-'):
            L3_posts.append(f)
        elif f.startswith('Citizen L320'):
            L320_posts.append(f)
        elif f.startswith('Miyano'):
            Miyano_posts.append(f)
        else:
            other_posts.append(f)

    # Determine if there are any posts to display (excluding common and sketcher)
    has_displayable_posts = bool(L1_posts or L2_posts or L3_posts or L320_posts or Miyano_posts or other_posts)

    if not has_displayable_posts:
        dropdown_command_input.isVisible = False
        return

    dropdown_command_input.isVisible = True # Ensure dropdown is visible if there are posts

    tempDir = tempfile.gettempdir()
    tempf = os.path.join(tempDir, 'citizenPost.txt')
    autoselect = "nothing"
    if os.path.exists(tempf):
        with open(tempf, 'r') as openF:
            autoselect = openF.read().strip()

    # Helper function to add a group of posts to the dropdown
    def add_group_items(label, group_list, prefix=""):
        if not group_list:
            return
        # Add a label-like entry to simulate a separator, make it non-selectable
        separator_item = dropdown_listItems.add('────────── ' + label + ' ──────────', False, '')
        separator_item.isEnabled = False
        for f in sorted(group_list):
            display = f.replace(prefix, '').rstrip('.cps')
            # Add indentation for a "folder" effect
            display = '    ' + display
            is_selected = (f.lower() == autoselect.lower())
            dropdown_listItems.add(display, is_selected, '')

    # Grouping for Sliding Heads (Citizen)
    if L1_posts or L2_posts or L3_posts or L320_posts:
        sliding_head_separator = dropdown_listItems.add('────────── Sliding Heads ──────────', False, '')
        sliding_head_separator.isEnabled = False
        add_group_items('L10 range', L1_posts, "Citizen ")
        add_group_items('L20 range', L2_posts, "Citizen ")
        add_group_items('L32 range', L3_posts, "Citizen ")
        add_group_items('L320 range', L320_posts, "Citizen ")

    # Grouping for Fixed Heads (Miyano)
    if Miyano_posts:
        fixed_head_separator = dropdown_listItems.add('────────── Fixed Heads ──────────', False, '')
        fixed_head_separator.isEnabled = False
        add_group_items('Miyano range', Miyano_posts, "Miyano ")

    


# ACTION WHEN USER MODIFIED FORM
class formUpdatedEventHandler(adsk.core.InputChangedEventHandler):
    def __init__(self):
        super().__init__()
    def notify(self, args):
        app = adsk.core.Application.get()
        ui  = app.userInterface
        eventArgs = adsk.core.InputChangedEventArgs.cast(args)
        changedInput = eventArgs.input # This is the specific CommandInput that changed
        global selected_post, L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts

        try:
            if changedInput.id == 'select_post':
                dropDownInput = adsk.core.DropDownCommandInput.cast(changedInput)
                object_items = dropDownInput.listItems

                selected_post = 'Select' # Default or invalid state

                # Check the newly selected item
                for item in object_items:
                    if item.isSelected:
                        # If the selected item is a separator (either general or the new "Sliding Heads"/"Fixed Heads" separators)
                        if item.name.startswith('──────────'):
                            ui.messageBox("Please select a machine from the list.", "Invalid Selection")
                            item.isSelected = False # Attempt to deselect the separator
                            selected_post = 'Select' # Ensure no invalid post is set
                            break # Exit the loop as we've handled the invalid selection
                        else:
                            # Reconstruct the original filename from the displayed name
                            original_name_stripped = item.name.lstrip(' ') # Remove indentation spaces first
                            
                            # Determine the original prefix and construct the full filename
                            found_post = False
                            for f in L1_posts + L2_posts + L3_posts + L320_posts:
                                if f.replace('Citizen ', '').rstrip('.cps') == original_name_stripped:
                                    selected_post = f
                                    found_post = True
                                    break
                            
                            if not found_post:
                                for f in Miyano_posts:
                                    if f.replace('Miyano ', '').rstrip('.cps') == original_name_stripped:
                                        selected_post = f
                                        found_post = True
                                        break

                            if not found_post: # Check other_posts if not found in Citizen or Miyano
                                for f in other_posts:
                                    if f.rstrip('.cps') == original_name_stripped:
                                        selected_post = f
                                        found_post = True
                                        break
                            
                            break # A valid item was selected, so we're good
# Toggle visibility based on post type
                if selected_post.startswith('Miyano'):
                    miyanoGroup.isVisible = True
                    citizenGroup.isVisible = False
                else:
                    miyanoGroup.isVisible = False
                    citizenGroup.isVisible = True
                
        except Exception as err:
            if ui:
                ui.messageBox(err.args[0])

# ACTION WHEN USER CLICKS OK IN THE CONFIGURATOR DIALOG
class selectCitizenPostExecutedEventHandler(adsk.core.CommandEventHandler):
    def __init__(self):
        super().__init__()
    def notify(self, args):
        app = adsk.core.Application.get()
        ui  = app.userInterface
        doc = app.activeDocument
        products = doc.products
        cam = products.itemByProductType('CAMProductType')
        updateAttributes()
        try:
            operationCollection = adsk.core.ObjectCollection.create()
            for setup in cam.setups:
                if setup.isSelected:
                    operationCollection.add(setup)
                else:
                    children = getChildren(setup)
                    for child in children:
                        operationCollection.add(child)

            # Ensure selected_post is not a separator before passing to postProcess
            if selected_post and not selected_post.startswith('──────────') and selected_post != 'Select':
                postProcess(collection=operationCollection, cpsPath=os.path.join(posts_fldr, selected_post), outputFolder=output_fldr,viewResult=True)
            else:
                ui.messageBox("Please select a valid post processor.", "Selection Required")

        except Exception as err:
            if ui:
                ui.messageBox('There was an error with post processing, please report to your support channel')
                ui.messageBox(err.args[0])

def getChildren(parent):
    children = parent.children
    objCollection = adsk.core.ObjectCollection.create()
    for child in children:
        if child.classType == adsk.cam.CAMFolder.classType or child.classType == adsk.cam.CAMPattern.classType:
            if child.isSelected:
                objCollection.add(child)
            else:
                newColl = getChildren(child)
                for newC in newColl:
                    objCollection.add(newC)
        elif child.classType == adsk.cam.Operation.classType:
            if child.isSelected:
                objCollection.add(child)
    return objCollection

# Stop function deletes the add-in button from Fusion
def endApp(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui  = app.userInterface

        CAMActionPan = ui.allToolbarPanels.itemById('CAMActionPanel')
        CAMManagePan = ui.allToolbarPanels.itemById('CAMManagePanel')
        dropDown = CAMManagePan.controls.itemById('ddAutoConfig')

        # Delete the drop down buttons
        if dropDown:
            selectCitizenPostButton2 = dropDown.controls.itemById('selectCitizenPost')
            if selectCitizenPostButton2:
                selectCitizenPostButton2.deleteMe()
            # Delete the drop-down too
            dropDown.deleteMe()

        # Delete the button displayed in the ACTIONS panel
        selectCitizenPostButtonControl1 = CAMActionPan.controls.itemById('selectCitizenPost')
        if selectCitizenPostButtonControl1:
            selectCitizenPostButtonControl1.deleteMe()

        # Delete the Command Definitions
        selectCitizenPostcmdDef = ui.commandDefinitions.itemById('selectCitizenPost')
        if selectCitizenPostcmdDef:
            selectCitizenPostcmdDef.deleteMe()

    except Exception as err:
        if ui:
            ui.messageBox(err.args[0])

def stringInput(val):
    return adsk.core.ValueInput.createByString(str(val))

def boolInput(val):
    return adsk.core.ValueInput.createByBoolean(val)

def getPostProperties():
    properties = adsk.core.NamedValues.create()
    if selected_post.startswith('Miyano'):
        properties.add("miyano_showSequenceNumbers", stringInput(bool_miyano_showSequenceNumbers.value))
        properties.add("miyano_optionalStop", stringInput(bool_miyano_optionalStop.value))
        properties.add("miyano_useRadius", stringInput(bool_miyano_useRadius.value))
        properties.add("miyano_subroutineAll", stringInput(bool_miyano_subroutineAll.value))
        properties.add("miyano_useParametricFeed", stringInput(bool_miyano_parametricFeed.value))
        properties.add("miyano_leaveSpindleRunning", stringInput(bool_miyano_spindleRunning.value))
        properties.add("miyano_sequenceNumberStart", adsk.core.ValueInput.createByReal(spinner_miyano_sequenceNumberStart.value))
        properties.add("miyano_sequenceNumberIncrement", adsk.core.ValueInput.createByReal(spinner_miyano_sequenceNumberInc.value))
        properties.add("miyano_maximumSpindleSpeed", adsk.core.ValueInput.createByReal(spinner_miyano_maxSpindle.value))
        return properties
    if selected_post.startswith('Citizen'):
        properties.add("showSequenceNumbers", stringInput(bool_showSequenceNumbers.value))
        properties.add("optionalStop", stringInput(bool_optionalStop.value))
        properties.add("useRadius", stringInput(bool_useRadius.value))
        properties.add("subroutineAll", stringInput(bool_subroutineAll.value))
        properties.add("useG50OnGang", stringInput(bool_useG50OnGang.value))
        properties.add("useParametricFeed", stringInput(bool_parametricFeed.value))
        properties.add("leaveSpindleRunning", stringInput(bool_spindleRunning.value))
        properties.add("subSpindlePhaseAngle", adsk.core.ValueInput.createByReal(spinner_subSpindlePhaseAngle.value))
        properties.add("increaseBAxisStroke", stringInput(bool_increaseBAxisStroke.value))
        properties.add("sequenceNumberStart", adsk.core.ValueInput.createByReal(spinner_sequenceNumberStart.value))
        properties.add("sequenceNumberIncrement", adsk.core.ValueInput.createByReal(spinner_sequenceNumberInc.value))
        properties.add("maximumSpindleSpeed", adsk.core.ValueInput.createByReal(spinner_maxSpindle.value))
        properties.add("increaseBAxisStroke", stringInput(bool_increaseBAxisStroke.value))
    return properties

def clearOutputFolder(folder):
    failedFiles = 0
    for fileName in os.listdir(folder):
        file_path = os.path.join(folder, fileName)
        try:
            os.remove(file_path)
        except:
            failedFiles += 1

def updateAttributes():
    updateAttribute("showSequenceNumbers", bool_showSequenceNumbers.value)
    updateAttribute("optionalStop", bool_optionalStop.value)
    updateAttribute("useRadius", bool_useRadius.value)
    updateAttribute("subroutineAll", bool_subroutineAll.value)
    updateAttribute("useG50OnGang", bool_useG50OnGang.value)
    updateAttribute("increaseBAxisStroke", bool_increaseBAxisStroke.value)
    updateAttribute("useParametricFeed", bool_parametricFeed.value)
    updateAttribute("leaveSpindleRunning", bool_spindleRunning.value)
    updateAttribute("subSpindlePhaseAngle", spinner_subSpindlePhaseAngle.value)
    updateAttribute("sequenceNumberStart", spinner_sequenceNumberStart.value)
    updateAttribute("sequenceNumberIncrement", spinner_sequenceNumberInc.value)
    updateAttribute("maximumSpindleSpeed", spinner_maxSpindle.value)
    updateAttribute("increaseBAxisStroke", bool_increaseBAxisStroke.value)

    updateAttribute("miyano_showSequenceNumbers", bool_miyano_showSequenceNumbers.value)
    updateAttribute("miyano_optionalStop", bool_miyano_optionalStop.value)
    updateAttribute("miyano_useRadius", bool_miyano_useRadius.value)
    updateAttribute("miyano_subroutineAll", bool_miyano_subroutineAll.value)
    updateAttribute("miyano_useParametricFeed", bool_miyano_parametricFeed.value)
    updateAttribute("miyano_leaveSpindleRunning", bool_miyano_spindleRunning.value)
    updateAttribute("miyano_sequenceNumberStart", spinner_miyano_sequenceNumberStart.value)
    updateAttribute("miyano_sequenceNumberIncrement", spinner_miyano_sequenceNumberInc.value)
    updateAttribute("miyano_maximumSpindleSpeed", spinner_miyano_maxSpindle.value)

    global selected_post
    tempDir = tempfile.gettempdir()
    tempf = os.path.join(tempDir, 'citizenPost.txt')
    f = open(tempf, 'w')
    f.write(selected_post)
    f.close()

def updateAttribute(name, value):
    app = adsk.core.Application.get()
    doc = app.activeDocument
    attr = doc.attributes
    attr.add('citizen', name, str(value))
    attr.add('miyano', name, str(value))

def postProcess(collection=None, programName='1001', cpsPath=None, outputFolder=os.path.join('C:', 'temp', 'post'), viewResult=False): # Run the postprocessing task
    app = adsk.core.Application.get()
    ui = app.userInterface
    doc = app.activeDocument
    cam = doc.products.itemByProductType('CAMProductType')

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
            postInput = adsk.cam.PostProcessInput.create("opdraw", os.path.join(os.path.dirname(__file__), 'posts', "toolpath sketcher.cps"), outputFolder, units)
            postInput.isOpenInEditor = False
            cam.postProcess(collection, postInput)
            # specify the program name, post configuration to use and a folder destination for the nc file
            logName = programName + '.log'
            logPath = os.path.join(cam.temporaryFolder, programName + '.log')

            for path, subdirs, files in os.walk(cam.temporaryFolder):
                for name in files:
                    if '.log' in name:
                        os.remove(os.path.join(path, name))
            if os.path.exists(logPath):
                os.remove(logPath)
            if select_units.selectedItem.name == 'IN':
                units = adsk.cam.PostOutputUnitOptions.InchesOutput
            postInput = adsk.cam.PostProcessInput.create(programName, cpsPath, outputFolder, units)
            postInput.postProperties = getPostProperties()

            postInput.isOpenInEditor = False
            cam.postProcess(collection, postInput)
            time.sleep(3)
            try:
                for path, subdirs, files in os.walk(cam.temporaryFolder):
                    for name in files:
                        if logName in name:
                            logPath = os.path.join(path, name)
                if os.path.exists(logPath) and not os.path.exists(os.path.join(outputFolder, programName + '.txt')):
                    f = open(logPath, 'r')
                    lines = f.readlines()
                    f.close()
                    errorString = ''
                    for line in lines:
                        if 'Error:' in line and not 'Failed to invoke' in line and not 'TypeError' in line and not 'Failed to execute' in line and not 'Error at' in line:
                            errorArray = line.split(':', 2)
                            errorString += errorArray[len(errorArray) - 1].strip() + '\n'
                    if errorString == '':
                        errorString = 'There was an error with post processing, please report to your support channel'
                    ui.messageBox("ABSC" + errorString)
                else:
                    ui.messageBox('Export successful')
            except:
                ui.messageBox('There was an error with post processing, please report to your support channel')

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
            data = json.loads(args.data)
            selected_machine = data.get("selectedImage")
            form = data.get("formValues", {})

            if not selected_machine:
                ui.messageBox("No machine selected.")
                return

            cps_file = find_matching_post(selected_machine)
            if not cps_file:
                ui.messageBox(f"No post processor found for: {selected_machine}")
                return

            global selected_post, posts_fldr, output_fldr
            selected_post = cps_file

            apply_form_options(form)

            doc = app.activeDocument
            cam = doc.products.itemByProductType('CAMProductType')
            operationCollection = adsk.core.ObjectCollection.create()
            for setup in cam.setups:
                if setup.isSelected:
                    operationCollection.add(setup)

            if operationCollection.count == 0:
                ui.messageBox("Please select a setup in the CAM workspace before submitting.")
                return

            if selected_post:
                postProcess(
                    collection=operationCollection,
                    cpsPath=os.path.join(posts_fldr, selected_post),
                    outputFolder=output_fldr,
                    viewResult=True
                )
                palette = ui.palettes.itemById('citizenPalette')
                if palette:
                    palette.isVisible = False
            else:
                ui.messageBox("Post processor not selected.")
        except Exception as e:
            ui.messageBox(f"HTML Handler Error:\n{str(e)}")


def find_matching_post(machine_name):
    global L1_posts, L2_posts, L3_posts, L320_posts, Miyano_posts, other_posts
    all_posts = L1_posts + L2_posts + L3_posts + L320_posts + Miyano_posts + other_posts
    for f in all_posts:
        simplified = f.replace("Citizen ", "").replace("Miyano ", "").replace(".cps", "")
        if simplified.lower() == machine_name.lower():
            return f
    return None


def apply_form_options(form):
    global bool_showSequenceNumbers, bool_optionalStop, bool_useRadius, bool_parametricFeed
    global bool_spindleRunning, bool_useG50OnGang, bool_increaseBAxisStroke
    global spinner_sequenceNumberStart, spinner_sequenceNumberInc, spinner_maxSpindle
    global spinner_subSpindlePhaseAngle, select_units

    def get_bool(name):
        return form.get(name) in ['true', 'on', 'True']

    def get_num(name, default=0):
        try:
            return float(form.get(name, default))
        except:
            return default

    if select_units and select_units.listItems:
        if form.get("outputUnits") == "in":
            select_units.listItems[0].isSelected = False
            select_units.listItems[1].isSelected = True
        else:
            select_units.listItems[0].isSelected = True
            select_units.listItems[1].isSelected = False

    bool_showSequenceNumbers.value     = get_bool("useSequence")
    bool_optionalStop.value            = get_bool("optionalStop")
    bool_useRadius.value               = get_bool("radiusArcs")
    bool_parametricFeed.value          = get_bool("parametricFeed")
    bool_spindleRunning.value          = get_bool("leaveSpindles")
    bool_useG50OnGang.value            = get_bool("g50Gang")
    bool_increaseBAxisStroke.value     = get_bool("increaseBStroke")

    spinner_sequenceNumberStart.value  = get_num("startSeqNum", 1)
    spinner_sequenceNumberInc.value    = get_num("seqIncrement", 1)
    spinner_maxSpindle.value           = get_num("maxSpindleSpeed", 5000)
    spinner_subSpindlePhaseAngle.value = get_num("subPhaseAngle", 0)

    updateAttributes()
