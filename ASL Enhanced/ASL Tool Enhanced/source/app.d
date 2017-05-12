import dlangui, dlangui.dialogs.dialog, dlangui.core.logger, dlangui.widgets.widget, dlangui.widgets.metadata;
import std.algorithm, std.string, std.array, std.conv, std.file, std.typecons, std.functional, std.json, std.path;

mixin APP_ENTRY_POINT;

enum Actions {
  File = 1,
  OpenGCT,
  SaveGCT,
  OpenDialogClose,
  SaveDialogClose,
  Import,
  Export,
  ImportDialogClose,
  ExportDialogClose,
  Tools,
  Reinsert,
  ViewASL,
  Help,
  About,
}

enum Data {
  Pac, Rel
}

alias ComboButton = Tuple!(string, "name", uint, "value");
static immutable ComboButton[] COMBO_BUTTONS = [
  tuple("A",           8),
  tuple("B",           9),
  tuple("X",           10),
  tuple("Y",           11),
  tuple("L",           6),
  tuple("R",           5),
  tuple("Z",           4),
  tuple("D-pad left",  0),
  tuple("D-pad right", 1),
  tuple("D-pad up",    3),
  tuple("D-pad down",  2),
  tuple("Start",       12)
];

alias StageEntry = Tuple!(string, "name",    ComboEntry[], "combos", ubyte, "numRandom");
alias ComboEntry = Tuple!(uint,   "buttons", char,         "letter");

static immutable BUTTON_STRINGS = ["W", "E", "S", "N", "Z", "R", "L", "", "A", "B", "X", "Y", "St"];

////////
// Globals
////////

CheckBox[] comboButtonBoxes;

StageEntry[] stageEntries, pacStages, relStages;
dstring[]    stageEntryNames;
Data currentData;

dstring[] comboNames;

Window   mainWindow;
MainMenu mainMenu;

StringListWidget listStage, listCombo;
Button           btnAddStage, btnRemoveStage, btnAddCombo, btnRemoveCombo;
EditLine         lineRandomNum, lineLetter;
ComboEdit        comboStage;
RadioButton      radioPacData, radioRelData, radioRandom, radioButtonCombos;

string openedFile = "";

int selectedStageIndex, selectedComboIndex;

////////
// Main GUI
////////

extern (C) int UIAppMain(string[] args) {
  ////
  // Make main window
  ////

  mainWindow = Platform.instance.createWindow("ASL Tool Enhanced", null, 1u, 750, 600);

  mainWindow.mainWidget = parseML(import("mainWindow.dml"));

  ////
  // Menu items
  ////

  MenuItem mainMenuItems = new MenuItem;

  ///

  MenuItem fileItem = new MenuItem(new Action(Actions.File, "File"d));

  fileItem.add(new Action(Actions.OpenGCT, "Open GCT..."d,        "gct-open", KeyCode.KEY_O, KeyFlag.Control));
  fileItem.add(new Action(Actions.SaveGCT, "Save GCT"d,           "gct-save", KeyCode.KEY_S, KeyFlag.Control));
  fileItem.add(new Action(Actions.Import,  "Import ASL data..."d, "data-import"));
  fileItem.add(new Action(Actions.Export,  "Export ASL data..."d, "data-export"));

  fileItem.menuItemClick = (MenuItem item) {
    if      (item.id == Actions.OpenGCT) openGCT();
    else if (item.id == Actions.SaveGCT) saveGCT();
    return true;
  };

  ///

  MenuItem helpItem = new MenuItem(new Action(Actions.Help, "Help"d));

  helpItem.add(new Action(Actions.About, "About"d, "about"));

  helpItem.menuItemClick = (MenuItem item) {
    if (item.id == Actions.About) {
      mainWindow.showMessageBox("About ASL Tool Enhanced"d,
                                "ASL Tool Enhanced v1.0\n
                                 written by TheGag96/codes\n
                                 (original tool by Mewtwo2000)
                                 (ASL credit: Dantarion, Almas, wiiztec, Magus, PyotrLuzhin)"d);
    }
    return true;
  };

  ///

  MenuItem toolsItem = new MenuItem(new Action(Actions.Tools, "Tools"d));

  toolsItem.add(new Action(Actions.Reinsert, "Reinsert ASL code..."d, "reinsert"));
  toolsItem.add(new Action(Actions.ViewASL,  "View ASL config"d,      "view-asl"));

  toolsItem.menuItemClick = (MenuItem item) {
    if      (item.id == Actions.Reinsert) reinsertGCT();
    else if (item.id == Actions.ViewASL)  viewASLConfig();
    return true;
  };

  ///

  mainMenuItems.add(fileItem);
  mainMenuItems.add(toolsItem);
  mainMenuItems.add(helpItem);
  
  findWidget!mainMenu;
  mainMenu.menuItems = mainMenuItems;

  ////
  // Lists
  ////

  findWidget!listStage;
  findWidget!listCombo;

  listStage.itemClick   = (Widget w, int index) { selectStage(index);   return true; };
  listCombo.itemClick   = (Widget w, int index) { selectCombo(index);   return true; };

  ////
  // Buttons
  ////

  findWidget!btnAddStage;
  findWidget!btnAddCombo;
  findWidget!btnRemoveStage;
  findWidget!btnRemoveCombo;

  btnAddStage.click   = (Widget w) { addStage();   return true; };
  btnAddCombo.click   = (Widget w) { addCombo();   return true; };
  
  btnRemoveStage.click   = (Widget w) { removeStage();   return true; };
  btnRemoveCombo.click   = (Widget w) { removeCombo();   return true; };

  ////
  // Radio buttons
  ////

  findWidget!radioPacData;
  findWidget!radioRelData;
  findWidget!radioButtonCombos;
  findWidget!radioRandom;

  ////
  // Fields
  ////

  findWidget!lineRandomNum;
  findWidget!lineLetter;
  findWidget!comboStage;

  //comboStage.contentChange       = (EditableContent content) { updateStageName(); };
  lineLetter.contentChange         = (EditableContent content) { updateLetter(); };
  lineRandomNum.contentChange         = (EditableContent content) { updateRandomNum(); };
  //comboComboSetlist.itemClick       = (Widget w, int index) { updateComboSetlist(index); return true; };

  lineLetter.enabled = false;

  //disableStageStuff();

  ////
  // Combo button checkboxes
  ////

  VerticalLayout layoutCombo;
  findWidget!layoutCombo;

  foreach (x; 0..COMBO_BUTTONS.length) {
    comboButtonBoxes ~= new CheckBox(format("combo_button_%d", (1 << COMBO_BUTTONS[x].value)), format(COMBO_BUTTONS[x].name).to!dstring);
    comboButtonBoxes[x].checkChange = (Widget w, bool b) { return updateComboButton(w, b); };
    comboButtonBoxes[x].enabled = false;
  }

  layoutCombo.addChildren(cast(Widget[]) comboButtonBoxes);

  ////
  // We're ready to go!
  ////

  mainWindow.show();

  return Platform.instance.enterMessageLoop();
}


////////
// UI interaction
////////

void openGCT() {
  
}

void saveGCT() {

}

void reinsertGCT() {

}

void viewASLConfig() {

}

////
// Selecting
////

void selectStage(int index) {
  auto stage = stageEntries[index];

  comboStage.text = stage.name.to!dstring;
  listStage.selectItem(index);

  //avoid allocation as much as possible
  comboNames.length = stage.combos.length;

  foreach (i; 0..comboNames.length) {
    comboNames[i] = memoize!getComboString(stage.combos[i].buttons);
  }

  listCombo.items = comboNames;

  comboStage.enabled     = true;
  btnAddCombo.enabled    = true;
  btnRemoveCombo.enabled = true;

  lineRandomNum.text = stage.numRandom.to!dstring;

  if (stage.numRandom == 0) {
    radioButtonCombos.checked = true;
    radioRandom.checked       = false;
    lineRandomNum.enabled     = false;
  }
  else {
    radioButtonCombos.checked = false;
    radioRandom.checked       = true;
    lineRandomNum.enabled     = true;
  }

  if (stage.combos.length) selectCombo(0);
}

void selectCombo(int index) {
  comboButtonBoxes.each!(x => x.enabled = true);
  lineLetter.enabled = true;

  auto stageIndex = listStage.selectedItemIndex;
  auto selCombo = stageEntries[stageIndex].combos[index].buttons;

  foreach (i; 0..COMBO_BUTTONS.length) {
    comboButtonBoxes[i].checked = cast(bool) ((1 << COMBO_BUTTONS[i].value) & selCombo);
  }

  lineLetter.text = ""d ~ stageEntries[stageIndex].combos[index].letter;

  listCombo.selectItem(index);
}

////
// Adding
////

void addStage() {
  stageEntries ~= StageEntry("stage", [/*ComboEntry(0x0040, 'Z')*/], 0);
  stageEntryNames ~= stageEntries[$-1].name.to!dstring;
  listStage.items = stageEntryNames;

  comboStage.enabled        = true;
  btnAddCombo.enabled       = true;
  btnRemoveCombo.enabled    = true;
  radioRandom.enabled       = true;
  radioButtonCombos.enabled = true;

  if (stageEntries.length == 1) selectStage(0);
}

void addCombo() {
  stageEntries[listStage.selectedItemIndex].combos ~= ComboEntry(0x0040, 'Z');

  comboNames     ~= "L+A";
  listCombo.items = comboNames;
}


void removeStage() {
  if (stageEntries.length == 0) return;

  auto index = listStage.selectedItemIndex;

  stageEntries    = stageEntries.remove(index);
  stageEntryNames = stageEntryNames.remove(index);
  listStage.items = stageEntryNames;

  if (stageEntries.length == 0) {
    disableStageStuff();
  }
  else {
    if (index >= stageEntries.length) index--;
    listStage.selectItem(index);
    selectStage(index);
  }
}

////
// Removing
////

void removeCombo() {
  auto stageIndex = listStage.selectedItemIndex,
       comboIndex = listCombo.selectedItemIndex;

  if (comboNames.length == 0) {
    //mainWindow.showMessageBox("Whoops!", "Stages must have at least one combo."d);
    return;
  }

  comboNames                      = comboNames.remove(comboIndex);
  stageEntries[stageIndex].combos = stageEntries[stageIndex].combos.remove(comboIndex);

  listCombo.items = comboNames;

  if (comboIndex >= comboNames.length) comboIndex--;
  listCombo.selectItem(comboIndex);
  selectCombo(comboIndex);
}

////
// Updating
////

void updateStageName() {
  if (stageEntries.length == 0 || comboStage.text == ""d) return;

  auto index               = listStage.selectedItemIndex;
  stageEntryNames[index]   = comboStage.text;
  stageEntries[index].name = stageEntryNames[index].to!string;
  listStage.items          = stageEntryNames;
  listStage.selectItem(index);
}


bool updateComboButton(Widget w, bool b) {
  auto stageIndex = listStage.selectedItemIndex;
  auto comboIndex = listCombo.selectedItemIndex;
  auto checkVal   = w.id[13..$].to!uint;
  auto currentVal = stageEntries[stageIndex].combos[comboIndex].buttons;

  currentVal = (currentVal & ~checkVal) | (b ? checkVal : 0);

  stageEntries[stageIndex].combos[comboIndex].buttons = currentVal;
  comboNames[comboIndex] = memoize!getComboString(currentVal);
  listCombo.items = comboNames;
  listCombo.selectItem(comboIndex);

  return true;
}

void updateRandomNum() {

}

void updateLetter() {

}

////////
// Helper
////////

void findWidget(alias name)() {
  name = mainWindow.mainWidget.childById!(typeof(name))(name.stringof);
}

dstring getComboString(uint combo) {
  auto builder = appender!dstring;
  if (combo == 0) {
    builder.put("Default"d);
  }
  else {
    bool first = true;
    foreach (i; 0..13) {
      if ((1 << i) & combo) {
        if (first) first = false;
        else       builder.put('+');
        
        builder.put(BUTTON_STRINGS[i].to!dstring);
      }
    }
  }

  return builder.data;
}

void disableStageStuff() {
  comboStage.text     = ""d;
  lineRandomNum.text  = ""d;

  comboStage.enabled        = false;
  lineRandomNum.enabled     = false;
  radioRandom.enabled       = false;
  radioButtonCombos.enabled = false;
  btnAddCombo.enabled       = false;
  btnRemoveCombo.enabled    = false;
  lineLetter.enabled        = false;

  comboButtonBoxes.each!(x => x.enabled = false);

  comboNames.length = 0;
  listCombo.items   = comboNames;
}

////////
// Compile-time only
////////

//format a ubyte array as a string for easier reading
enum Bytes(string s) = s.splitter.map!(x => x.to!ubyte(16)).array;
