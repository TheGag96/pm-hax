import dlangui, filedlg, dlangui.dialogs.dialog, dlangui.core.logger, dlangui.widgets.widget, dlangui.widgets.metadata;
import std.algorithm, std.string, std.array, std.conv, std.file, std.typecons, std.functional, std.json, std.path;
import codegen;

mixin APP_ENTRY_POINT;

enum Actions {
  File = 1,
  OpenInfo,
  SaveInfo,
  OpenDialogClose,
  SaveDialogClose,
  Build,
  Generate,
  Help,
  About,
}

////////
// Globals
////////

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

CheckBox[] comboButtonBoxes;

StageEntry[] stageEntries;
dstring[]    stageEntryNames;

dstring[] comboNames;

SongList[]   songLists;
dstring[]    songListNames;

Window  mainWindow;
MainMenu mainMenu;

StringListWidget listStage, listCombo, listSetlist;
Button btnAddStage, btnRemoveStage, btnAddCombo, btnRemoveCombo, btnAddSetlist, btnRemoveSetlist;
EditLine lineStageName, lineStageID, lineSetlistStartID, lineSetlistNumSongs, lineSetlistName;
ComboEdit comboComboSetlist;

string openedFile = "";

int selectedStageIndex, selectedComboIndex, selectedSetlistIndex;

////////
// Main GUI
////////

extern (C) int UIAppMain(string[] args) {
  mixin(registerWidgets!(SourceEdit)("void doSrcEditRegister")
          .replace("dlangui.widgets.srcedit", ""));

  doSrcEditRegister();

  ////
  // Make main window
  ////

  mainWindow = Platform.instance.createWindow("SFC Generator", null, 1u, 750, 600);

  version (Debug) {
    mainWindow.mainWidget = parseML(readText("views/mainWindow.dml"));
  }
  else {
    mainWindow.mainWidget = parseML(import("mainWindow.dml"));
  }
  
  ////
  // Menu items
  ////

  MenuItem mainMenuItems = new MenuItem;
  MenuItem fileItem = new MenuItem(new Action(Actions.File, "File"d));

  fileItem.add(new Action(Actions.OpenInfo, "Open song info file..."d, "info-open", KeyCode.KEY_O, KeyFlag.Control));
  fileItem.add(new Action(Actions.SaveInfo, "Save song info file as..."d, "info-save", KeyCode.KEY_S, KeyFlag.Control));

  fileItem.menuItemClick = (MenuItem item) {
    if      (item.id == Actions.OpenInfo) openInfoFile();
    else if (item.id == Actions.SaveInfo) saveInfoFile();
    return true;
  };

  MenuItem buildItem = new MenuItem(new Action(Actions.Build, "Build"d));
  buildItem.add(new Action(Actions.Generate, "Generate ASM"d, "generate"));

  buildItem.menuItemClick = (MenuItem item) {
    generateASM(); 
    return true;
  };
  
  MenuItem helpItem = new MenuItem(new Action(Actions.Help, "Help"d));
  helpItem.add(new Action(Actions.About, "About"d, "about"));

  helpItem.menuItemClick = (MenuItem item) {
    if (item.id == Actions.About) {
      mainWindow.showMessageBox("About SFC Generator"d, "SFC Generator v1.0\nwritten by TheGag96/codes"d);
    }
    return true;
  };

  mainMenuItems.add(fileItem);
  mainMenuItems.add(buildItem);
  mainMenuItems.add(helpItem);
  
  mainMenu = mainWindow.mainWidget.childById!MainMenu("mainMenu");
  mainMenu.menuItems = mainMenuItems;

  ////
  // Lists
  ////

  listStage   = mainWindow.mainWidget.childById!StringListWidget("listStage");
  listCombo   = mainWindow.mainWidget.childById!StringListWidget("listCombo");
  listSetlist = mainWindow.mainWidget.childById!StringListWidget("listSetlist");

  listStage.itemClick   = (Widget w, int index) { selectStage(index);   return true; };
  listCombo.itemClick   = (Widget w, int index) { selectCombo(index);   return true; };
  listSetlist.itemClick = (Widget w, int index) { selectSetlist(index); return true; };

  ////
  // Buttons
  ////

  btnAddStage      = mainWindow.mainWidget.childById!Button("btnAddStage");
  btnAddCombo      = mainWindow.mainWidget.childById!Button("btnAddCombo");
  btnAddSetlist    = mainWindow.mainWidget.childById!Button("btnAddSetlist");
  
  btnRemoveStage   = mainWindow.mainWidget.childById!Button("btnRemoveStage");
  btnRemoveCombo   = mainWindow.mainWidget.childById!Button("btnRemoveCombo");
  btnRemoveSetlist = mainWindow.mainWidget.childById!Button("btnRemoveSetlist");

  btnAddStage.click   = (Widget w) { addStage();   return true; };
  btnAddCombo.click   = (Widget w) { addCombo();   return true; };
  btnAddSetlist.click = (Widget w) { addSetlist(); return true; };
  
  btnRemoveStage.click   = (Widget w) { removeStage();   return true; };
  btnRemoveCombo.click   = (Widget w) { removeCombo();   return true; };
  btnRemoveSetlist.click = (Widget w) { removeSetlist(); return true; };

  ////
  // Fields
  ////

  lineStageName       = mainWindow.mainWidget.childById!EditLine("lineStageName");
  lineStageID         = mainWindow.mainWidget.childById!EditLine("lineStageID");
  lineSetlistName     = mainWindow.mainWidget.childById!EditLine("lineSetlistName");
  lineSetlistStartID  = mainWindow.mainWidget.childById!EditLine("lineSetlistStartID");
  lineSetlistNumSongs = mainWindow.mainWidget.childById!EditLine("lineSetlistNumSongs");
  comboComboSetlist   = mainWindow.mainWidget.childById!ComboEdit("comboComboSetlist");

  lineStageName.contentChange       = (EditableContent content) { updateStageName(); };
  lineStageID.contentChange         = (EditableContent content) { updateStageID(); };
  lineSetlistName.contentChange     = (EditableContent content) { updateSetlistName(); };
  lineSetlistStartID.contentChange  = (EditableContent content) { updateSetlistStartID(); };
  lineSetlistNumSongs.contentChange = (EditableContent content) { updateSetlistNumSongs(); };
  comboComboSetlist.itemClick       = (Widget w, int index) { updateComboSetlist(index); return true; };

  lineSetlistName.enabled     = false;
  lineSetlistStartID.enabled  = false;
  lineSetlistNumSongs.enabled = false;

  comboComboSetlist.enabled = false;

  disableStageStuff();

  ////
  // Combo button checkboxes
  ////

  auto layoutCombo = mainWindow.mainWidget.childById!VerticalLayout("layoutCombo");

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

////
// Info file I/O
////

void openInfoFile() {
  auto flags = FileDialogFlag.Open | DialogFlag.Modal | DialogFlag.Resizable;

  FileDialog dialog = new FileDialog(UIString("Choose an info file"d), mainWindow, null, flags);

  dialog.dialogResult = (Dialog d, const Action result) {
    auto filename = result.stringParam;
    if (!filename.length) return;

    JSONValue infoData;

    try {
      infoData = parseJSON(readText(filename));
    }
    catch (Exception e) {
      mainWindow.showMessageBox("Whoops!"d, "This is not a valid info file!"d);
      return;
    }

    stageEntries.length    = 0;
    songLists.length       = 0;
    stageEntryNames.length = 0;
    songListNames.length   = 0;
    comboNames.length      = 0;

    foreach (sl; infoData["setlists"].array) {
      SongList newOne;

      newOne.name     = sl["name"].str;
      newOne.startID  = cast(uint) sl["startID"].integer;
      newOne.numSongs = cast(uint) sl["numSongs"].integer;
     
      songLists ~= newOne;
    }

    foreach (se; infoData["stageEntries"].array) {
      StageEntry newStage;

      newStage.name = se["name"].str;
      newStage.id   = cast(uint) se["id"].integer;

      foreach (combo; se["combos"].array) {
        ComboEntry newCombo;

        newCombo.buttons      = cast(uint) combo["buttons"].integer;
        newCombo.songListName = combo["songListName"].str;

        newStage.combos ~= newCombo;
      }

      stageEntries ~= newStage;
    }

    stageEntryNames = stageEntries.map!(x => x.name.to!dstring).array;
    songListNames   = stageEntries.map!(x => x.name.to!dstring).array;

    listStage.items   = stageEntryNames;
    listSetlist.items = songListNames;

    if (stageEntries.length == 0) {
      disableStageStuff();
    }
    else {
      selectStage(0);
    }

    if (songLists.length == 0) {
      disableSetlistStuff();
    }
    else {
      selectSetlist(0);
    }
  };

  dialog.show();
}

void saveInfoFile() {
  auto flags = FileDialogFlag.Save | DialogFlag.Modal | DialogFlag.Resizable;

  auto dialog = new FileDialog(UIString("Save an info file"d), mainWindow, null, flags);

  dialog.dialogResult = (Dialog d, const Action result) {
    auto filename = result.stringParam;
    if (!filename.length) return;

    JSONValue infoData = JSONValue(["fileType" : "SFC Info"]);

    JSONValue[] jsonSetlists;

    foreach (sl; songLists) {
      jsonSetlists ~= JSONValue([
        "name"     : JSONValue(sl.name),
        "startID"  : JSONValue(sl.startID),
        "numSongs" : JSONValue(sl.numSongs)
      ]);
    }

    infoData.object["setlists"] = JSONValue(jsonSetlists);

    JSONValue[] jsonStageEntries;

    foreach (se; stageEntries) {
      JSONValue newStage = JSONValue([
        "name" : JSONValue(se.name),
        "id"   : JSONValue(se.id)
      ]);

      JSONValue[] jsonCombos;

      foreach (combo; se.combos) {
        jsonCombos ~= JSONValue([
          "buttons"      : JSONValue(combo.buttons),
          "songListName" : JSONValue(combo.songListName)
        ]);
      }

      newStage.object["combos"] = JSONValue(jsonCombos);

      jsonStageEntries ~= newStage;
    }

    infoData.object["stageEntries"] = JSONValue(jsonStageEntries);

    std.file.write(filename, infoData.toString());
  };

  dialog.show();
}

////
// Selecting
////

void selectStage(int index) {
  auto stageCombos = stageEntries[index].combos;

  lineStageName.text = stageEntries[index].name.to!dstring;
  lineStageID.text   = stageEntries[index].id.to!dstring(16);
  listStage.selectItem(index);

  //avoid allocation as much as possible
  comboNames.length = stageCombos.length;

  foreach (i; 0..comboNames.length) {
    comboNames[i] = memoize!getComboString(stageCombos[i].buttons);
  }

  listCombo.items = comboNames;

  lineStageName.enabled  = true;
  lineStageID.enabled    = true;
  btnAddCombo.enabled    = true;
  btnRemoveCombo.enabled = true;

  selectCombo(0);
}

void selectCombo(int index) {
  comboButtonBoxes.each!(x => x.enabled = true);
  comboComboSetlist.enabled = true;

  auto stageIndex = listStage.selectedItemIndex;
  auto selCombo = stageEntries[stageIndex].combos[index].buttons;

  foreach (i; 0..COMBO_BUTTONS.length) {
    comboButtonBoxes[i].checked = cast(bool) ((1 << COMBO_BUTTONS[i].value) & selCombo);
  }

  comboComboSetlist.text = stageEntries[stageIndex].combos[index].songListName.to!dstring;

  listCombo.selectItem(index);
}

void selectSetlist(int index) {
  lineSetlistName.text     = songLists[index].name.to!dstring;
  lineSetlistStartID.text  = songLists[index].startID.to!dstring(16);
  lineSetlistNumSongs.text = songLists[index].numSongs.to!dstring;
  listSetlist.selectItem(index);
}

////
// Adding
////

void addStage() {
  stageEntries ~= StageEntry(0, [ComboEntry(0, "")], "New stage");
  stageEntryNames ~= stageEntries[$-1].name.to!dstring;
  listStage.items = stageEntryNames;

  lineStageName.enabled  = true;
  lineStageID.enabled    = true;
  btnAddCombo.enabled    = true;
  btnRemoveCombo.enabled = true;

  if (stageEntries.length == 1) selectStage(0);
}

void addCombo() {
  stageEntries[listStage.selectedItemIndex].combos ~= ComboEntry(0, "");

  comboNames     ~= "Default";
  listCombo.items = comboNames;
}

void addSetlist() {
  string newName = format("New setlist %d", songLists.length+1);

  while (songLists.map!(x => x.name).canFind(newName)) {
    newName ~= " 2";
  }

  songLists              ~= SongList(0, 0, newName);
  songListNames          ~= newName.to!dstring;
  listSetlist.items       = songListNames;

  preserveAndUpdateComboSetlist();

  lineSetlistName.enabled     = true;
  lineSetlistStartID.enabled  = true;
  lineSetlistNumSongs.enabled = true;

  if (songLists.length == 1) selectSetlist(0);
}

////
// Removing
////

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

void removeCombo() {
  auto stageIndex = listStage.selectedItemIndex,
       comboIndex = listCombo.selectedItemIndex;

  if (comboNames.length == 1) {
    mainWindow.showMessageBox("Whoops!", "Stages must have at least one combo."d);
    return;
  }

  comboNames                      = comboNames.remove(comboIndex);
  stageEntries[stageIndex].combos = stageEntries[stageIndex].combos.remove(comboIndex);

  listCombo.items = comboNames;

  if (comboIndex >= comboNames.length) comboIndex--;
  listCombo.selectItem(comboIndex);
  selectCombo(comboIndex);
}

void removeSetlist() {
  if (songLists.length == 0) return;

  auto index = listSetlist.selectedItemIndex;

  songLists               = songLists.remove(index);
  songListNames           = songListNames.remove(index);
  preserveAndUpdateComboSetlist();
  listSetlist.items       = songListNames;

  if (songListNames.length == 0) { 
    disableSetlistStuff();
  }
  else {
    if (index >= songListNames.length) index--;
    selectSetlist(index);
  }
}

////
// Updating
////

void updateStageName() {
  if (stageEntries.length == 0 || lineStageName.text == ""d) return;

  auto index               = listStage.selectedItemIndex;
  stageEntryNames[index]   = lineStageName.text;
  stageEntries[index].name = stageEntryNames[index].to!string;
  listStage.items          = stageEntryNames;
  listStage.selectItem(index);
}

void updateStageID() {
  if (stageEntries.length == 0) return;
  
  try {
    stageEntries[listStage.selectedItemIndex].id = lineStageID.text.to!uint(16);
    //mainWindow.showMessageBox("f", stageEntries[listStage.selectedItemIndex].id.to!dstring);
  }
  catch (Exception e) { }
}

void updateSetlistName() {
  if (songLists.length == 0 || lineSetlistName.text == ""d || songListNames.canFind(lineSetlistName.text)) return;

  auto index              = listSetlist.selectedItemIndex;
  auto newName            = lineSetlistName.text.to!string;
  auto oldName            = songLists[index].name;

  foreach (ref stage; stageEntries) {
    foreach (ref combo; stage.combos) {
      if (combo.songListName == oldName) {
        combo.songListName = newName;
      }
    }
  }

  songListNames[index]    = lineSetlistName.text;
  songLists[index].name   = newName;
  listSetlist.items       = songListNames;

  preserveAndUpdateComboSetlist();

  listSetlist.selectItem(index);
}

void updateSetlistStartID() {
  if (songLists.length == 0) return;
  
  try {
    songLists[listSetlist.selectedItemIndex].startID = lineSetlistStartID.text.to!uint(16);
  }
  catch (Exception e) { }
}

void updateSetlistNumSongs() {
  if (songLists.length == 0) return;

  try {
    songLists[listSetlist.selectedItemIndex].numSongs = lineSetlistNumSongs.text.to!uint;
  }
  catch (Exception e) { }
}

void updateComboSetlist(int index) {
  if (songLists.length == 0 || stageEntries.length == 0) return;

  stageEntries[listStage.selectedItemIndex].combos[listCombo.selectedItemIndex].songListName = songLists[index].name;
  //comboComboSetlist.selectItem(index);
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

////
// What it's all about
////

void generateASM() {
  auto errorMsg = verify();

  if (errorMsg.length) {
    mainWindow.showMessageBox("Whoops!", errorMsg);
    return;
  }

  auto code = generateCode(stageEntries, songLists);

  auto asmWindow  = Platform.instance.createWindow("ASM output", mainWindow, 1u | WindowFlag.Modal, 500, 500);
  auto layout     = new VerticalLayout("asm_display_layout");
  auto asmSrc     = new SourceEdit("asm_src");
  auto btnSaveASM = new Button("btn_save_asm", "Save code to file"d);

  layout.layoutWidth  = FILL_PARENT;
  layout.layoutHeight = FILL_PARENT;
  layout.addChild(asmSrc);
  layout.addChild(btnSaveASM);

  asmWindow.mainWidget = layout;

  btnSaveASM.click = (Widget w) { 
    auto flags  = FileDialogFlag.Save | DialogFlag.Modal | DialogFlag.Resizable;
    auto dialog = new FileDialog(UIString("Save generated ASM code to file"d), mainWindow, null, flags);

    //dialog.filters = [FileFilterEntry(UIString("ASM file"d), "*.asm")];

    dialog.dialogResult = (Dialog d, const Action result) {
      auto filename = result.stringParam;
      //auto fd = cast(FileDialog) d;
      //asmWindow.showMessageBox("asdf", filename.to!dstring ~ "\n"d ~ fd.path.to!dstring ~ "\n"d ~ fd.filename.to!dstring ~ "\n"d ~ fd.text);
      if (!filename.length) return;

      std.file.write(filename, asmSrc.text.to!string);    
    };

    dialog.show();
    return true;
  };

  asmSrc.text = code.to!dstring;
  
  asmWindow.show();
}

dstring verify() {
  foreach (i, setlist; songLists) {
    if (songLists[i+1..$].map!(x => x.name).canFind(setlist.name)) {
      return format("A song list called '%s' was already defined!"d, setlist.name);
    }
  }

  foreach (entry; stageEntries) {
    bool foundDefault = false;

    foreach (combo; entry.combos) {
      if (combo.buttons == 0) {
        if (foundDefault) {
          return format("Stage '%s' can't have more than one default setlist!"d, entry.name);
        }
        else foundDefault = true;
      }

      if (combo.songListName.length == 0) {
        return format("Combo %s for stage '%s' doesn't have a setlist!"d, memoize!getComboString(combo.buttons), entry.name);
      }
      else if (!songLists.map!(x => x.name).canFind(combo.songListName)) {
        return format("Combo %s for stage '%s' has a setlist that doesn't exist!"d, memoize!getComboString(combo.buttons), entry.name);
      }
    }
  }

  return "";
}

////////
// Helper
////////

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
  lineStageName.text     = ""d;
  lineStageID.text       = ""d;
  comboComboSetlist.text = ""d;

  lineStageName.enabled     = false;
  lineStageID.enabled       = false;
  comboComboSetlist.enabled = false;
  btnAddCombo.enabled       = false;
  btnRemoveCombo.enabled    = false;

  comboButtonBoxes.each!(x => x.enabled = false);

  comboNames.length = 0;
  listCombo.items   = comboNames;
}

void disableSetlistStuff() {
  lineSetlistName.text     = ""d;
  lineSetlistStartID.text  = ""d;
  lineSetlistNumSongs.text = ""d;

  lineSetlistName.enabled     = false;
  lineSetlistStartID.enabled  = false;
  lineSetlistNumSongs.enabled = false;
}

void preserveAndUpdateComboSetlist() {
  //preserve comboComboSetlist text
  auto ccText             = comboComboSetlist.text;
  comboComboSetlist.items = songListNames;
  comboComboSetlist.text  = ccText;
}

////////
// Compile-time only
////////

//format a ubyte array as a string for easier reading
template Bytes(string s) {
  enum Bytes = s.splitter.map!(x => x.to!ubyte(16)).array;
}
