# Citizen Post Processor Add-in for Fusion 360

This add-in provides an HTML-based interface for selecting Citizen and Miyano post processors and generating NC code files.

## Installation

1. Copy the add-in folder to your computer
2. Enable the add-in in Fusion 360 using 'Manufacture' -> 'Utilities' -> AddIns
3. The "Output to Citizen" button will appear in the CAM Actions panel

## Output Folder Configuration

The add-in always outputs code that can be imported only into the Alkart Wizard


## Usage

1. Create CAM setups and operations in Fusion 360
2. Select the operations you want to post-process
3. Click the "Output to Citizen" button in the CAM Actions panel
4. Select your machine from the HTML interface
5. Configure post processor options
6. Click "Post" to generate NC code

## Supported Machines

- Citizen L10 Series (L12-VII)
- Citizen L20 Series (L220-VIII, L220-X, L220-XII, L32-VIII, L32-X, L32-XII, L212-X)
- Citizen L320 Series (L320-VIII, L320-X, L320-XII, L320-XIIB5)
- Miyano Machines (BNA-GTY, BNA-C, BNA-DHY, BNA-SY5, BNE-MSY, BNE-MYY, BNJ-SY6)

## Troubleshooting

- If the add-in doesn't load, check that all required files are present
- If NC files aren't visible in Alkart Wizard, please verify that the Import function exists - you may need to update the Alkart Wizard to the latest version.
