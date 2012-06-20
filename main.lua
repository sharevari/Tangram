--[[============================================================================
com.renoise.Tangram.xrnx/main.lua
============================================================================]]--


--------------------------------------------------------------------------------
-- menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry({
  name = "Main Menu:Tools:Tangram",
  invoke = function() show_gui() end 
})


--------------------------------------------------------------------------------
-- preferences
--------------------------------------------------------------------------------

local options = renoise.Document.create("TangramPreferences") {
  show_debug_prints = false,
  sections = 1,
  length = 8,
  spacing = 1,
  note_range_min = 48,
  note_range_max = 60,
  midi_in_channel = 0,
}

-- register this document as the main preferences for the tool:
renoise.tool().preferences = options


--------------------------------------------------------------------------------
-- midi mappings
--------------------------------------------------------------------------------

local MAX_STEPS = 32
local MAX_SPACING = 32

for step = 1, MAX_STEPS do
  renoise.tool():add_midi_mapping ({
    name = ("Tangram:Rotary Knobs:Knob %02d"):format(step),
    invoke = function(message) on_midi_knob_turned(step, message) end 
  })
end

for transpose = -24, -1 do
  renoise.tool():add_midi_mapping ({
    name = ("Tangram:Transpose Keys:Transpose %03d"):format(transpose),
    invoke = function(message) on_midi_transpose(transpose, message) end 
  })
end
for transpose = 0, 24 do
  renoise.tool():add_midi_mapping ({
    name = ("Tangram:Transpose Keys:Transpose %02d"):format(transpose),
    invoke = function(message) on_midi_transpose(transpose, message) end 
  })
end

renoise.tool():add_midi_mapping ({
  name = ("Tangram:Length:Increase"),
  invoke = function(message) on_midi_length_inced(message) end 
})
renoise.tool():add_midi_mapping ({
  name = ("Tangram:Length:Decrease"),
  invoke = function(message) on_midi_length_deced(message) end 
})

renoise.tool():add_midi_mapping ({
  name = ("Tangram:Spacing:Increase"),
  invoke = function(message) on_midi_spacing_inced(message) end 
})
renoise.tool():add_midi_mapping ({
  name = ("Tangram:Spacing:Decrease"),
  invoke = function(message) on_midi_spacing_deced(message) end 
})


--------------------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------------------

-- Invoked each time a new document (song) was created or loaded.
renoise.tool().app_new_document_observable:add_notifier(function()
  on_new_document();
end)


--------------------------------------------------------------------------------
-- helper functions
--------------------------------------------------------------------------------

local NOTE_NAMES = {
  "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"
}

--------------------------------------------------------------------------------

function number_to_note(number)
  if (number == 120) then
    return "OFF"
  elseif (number >= 0 and number <= 119) then
    return NOTE_NAMES[(number % 12) + 1] .. math.floor(number / 12)
  else
    return "???"
  end
end


--------------------------------------------------------------------------------

function note_to_number(note)
  local letter = string.sub(note, 1, 2)
  local octave = string.sub(note, 3, 3)
  for i = 1, 12 do
    if (letter == NOTE_NAMES[i]) then
      return 12 * octave + (i - 1)
    end
  end
  return -1
end


--------------------------------------------------------------------------------

function bcr_midi_out_port()

  --Input:
  --BCR2000 port 1 = messages from the BCR itself
  --BCR2000 port 2 = messages from the BCR's MIDI IN
  --BCR2000 port 3 = UNUSABLE DUMMY
  --
  --Output:
  --BCR2000 port 1 = messages to the BCR itself
  --BCR2000 port 2 = messages to the BCR's MIDI OUT A
  --BCR2000 port 3 = messages to the BCR's MIDI OUT B/THRU

  local bcr_out_port = nil;

  local outputs = renoise.Midi.available_output_devices()
  if not table.is_empty(outputs) then
    for i = 1, #outputs do
      local port_name = outputs[i];
      if (string.find(port_name, "BCR2000") ~= nil and
          string.find(port_name, "port 1") ~= nil) then
        bcr_out_port = port_name;
      end
    end  
  end

  return bcr_out_port;
  
end


--------------------------------------------------------------------------------

function bcr_sysex()

  local inputs = renoise.Midi.available_input_devices()
  local midi_in_device = nil
  
  if not table.is_empty(inputs) then
    local device_name = inputs[3]
    
    local function midi_callback(message)
      --print(("%s: got MIDI %X %X %X"):format(device_name, 
      --  message[1], message[2], message[3]))
      print("MIDI: ");
      rprint(message);
    end
  
    local function sysex_callback(message)
      --print(("%s: got MIDI %X %X %X"):format(device_name, 
      --  message[1], message[2], message[3]))
      print("Sysex: ");
      rprint(message);
    end

    -- note: sysex callback would be a optional 2nd arg...
    midi_in_device = renoise.Midi.create_input_device(
      device_name, midi_callback, sysex_callback)
    
    -- stop dumping with 'midi_device:close()' ...
  end
  
  local outputs = renoise.Midi.available_output_devices()

  if not table.is_empty(outputs) then
    local device_name = outputs[4]
    local midi_device = renoise.Midi.create_output_device(device_name)
    
    -- note on
    --midi_device:send {0x90, 0x10, 0x7F}

    -- $40 $7F should return the config of the current preset

    local midi_pre = {
      0xF0, 0x00, 0x20, 0x32,       -- sysex plus manufacturer ID
      0x7F,                         -- device ID (any)
      0x7F,                         -- model (any)
      0x20,                         -- this is a BCL message
      0x00, 0x00,                   -- sequence index
    }
   
    local midi_post = {
      0xF7,                         -- end of sysex
    }

    local bcl = {
      "$rev R",
      "$encoder 33",
      ".easypar CC 1 1 0 127 absolute",
      ".showvalue on",
      ".mode 1dot",
      ".resolution 127",
      ".default 0",
      "$end"
    }

      
    for i, line in ipairs(bcl) do
      local midi_msg = {};
            
      for j, byte in ipairs(midi_pre) do
        table.insert(midi_msg, byte);
      end
      
      midi_msg[9] = midi_msg[9] + (i - 1);
      
      print(midi_msg[9]);
      
      for j = 1, string.len(line) do
        table.insert(midi_msg, string.byte(line, j));
      end

      table.insert(midi_msg, midi_post[1]);

      midi_device:send(midi_msg);
      
    end

    midi_device:close()  
  end
  
end


--------------------------------------------------------------------------------
-- main tool
--------------------------------------------------------------------------------

local vb;
local knobs = {};
local last_played_line;
local midi_out = nil;

--------------------------------------------------------------------------------

function show_gui()

  local midi_out_port = bcr_midi_out_port();
  if (midi_out_port ~= nil) then
    midi_out = renoise.Midi.create_output_device(midi_out_port);
  end

  rprint(midi_out);

  local dialog = nil
  
  local DIALOG_MARGIN = 
    renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  
  local CONTENT_SPACING = 
    renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  
  local CONTENT_MARGIN = 
    renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
  
  local DEFAULT_CONTROL_HEIGHT = 
    renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT
  
  local DEFAULT_DIALOG_BUTTON_HEIGHT =
    renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  
  local DEFAULT_MINI_CONTROL_HEIGHT = 
    renoise.ViewBuilder.DEFAULT_MINI_CONTROL_HEIGHT
  
  local TEXT_ROW_WIDTH = 70
  
  local KNOB_SIZE = DEFAULT_CONTROL_HEIGHT * 2 + 3

  --if (not allow_opening_on_current_track()) then
  --  return;
  --end

  vb = renoise.ViewBuilder()

  local sections_length_row = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Note Range"
    },
    vb:valuebox {
      min = 0,
      max = 119,
      bind = options.note_range_min,
      tostring = function(value) return number_to_note(value) end,
      tonumber = function(str) return note_to_number(str) end
    },
    vb:valuebox {
      min = 0,
      max = 119,
      bind = options.note_range_max,
      tostring = function(value) return number_to_note(value) end,
      tonumber = function(str) return note_to_number(str) end
    },

    vb:space {width = 10},

    vb:text {
      width = 50,
      text = "Length"
    },
    vb:valuebox {
      min = 1,
      max = 32,
      id = "length",
      bind = options.length
    }
  }

  local range_spacing_row = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH + 60,
      text = "MIDI In Channel"
    },
    vb:valuebox {
      min = 0,
      max = 16,
      bind = options.midi_in_channel,
    },

    vb:space {width = 10},

    vb:text {
      width = 50,
      text = "Spacing"
    },
    vb:valuebox {
      min = 1,
      max = MAX_SPACING,
      bind = options.spacing
    }
  }

  local KNOB_MIN = 0
  local KNOB_MAX = 127
  local KNOB_DEFAULT = 0 

  for i = 1, MAX_STEPS do
    knobs[i] = vb:rotary({
      min = KNOB_MIN,
      max = KNOB_MAX,
      value = KNOB_DEFAULT,
      width = KNOB_SIZE,
      height = KNOB_SIZE,
      midi_mapping = ("Tangram:Rotary Knobs:Knob %02d"):format(i),
      notifier = function(value) on_gui_knob_turned(i, value) end,
      id = "knob" .. i
    })
  end

  local knob_row_1 = vb:row({})
  for i = 1, 8 do
    knob_row_1:add_child(knobs[i])
  end

  local knob_row_2 = vb:row({})
  for i = 9, 16 do
    knob_row_2:add_child(knobs[i])
  end

  local knob_row_3 = vb:row({})
  for i = 17, 24 do
    knob_row_3:add_child(knobs[i])
  end

  local knob_row_4 = vb:row({})
  for i = 25, 32 do
    knob_row_4:add_child(knobs[i])
  end

  local dialog_content = vb:column {
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
    
    sections_length_row,
    range_spacing_row,
    knob_row_1,
    knob_row_2,
    knob_row_3,
    knob_row_4,
  }
  
  dialog = renoise.app():show_custom_dialog("Tangram", dialog_content);

  -- initialise state
  on_length_changed();
  
  last_played_line = 1;
  
end


--------------------------------------------------------------------------------

_AUTO_RELOAD_DEBUG = function()
  show_gui()
end


--------------------------------------------------------------------------------

function on_sections_changed()
  if (options.sections.value == 1) then
    options.length.value = math.min(MAX_STEPS, options.length.value)
    vb.views.length.max = MAX_STEPS
  elseif (options.sections.value == 2) then
    options.length.value = math.min(MAX_STEPS / 2, options.length.value)
    vb.views.length.max = MAX_STEPS / 2
  elseif (options.sections.value == 3 or options.sections.value == 4) then
    options.length.value = math.min(MAX_STEPS / 4, options.length.value)
    vb.views.length.max = MAX_STEPS / 4
  end
end


--------------------------------------------------------------------------------

function on_length_changed()

  for i = 1, options.length.value do
    --knobs[i].active = true;
    knobs[i].visible = true;
  end
  for i = options.length.value + 1, MAX_STEPS do
    --knobs[i].active = false;
    knobs[i].visible = false;
  end

  rebuild_pattern_data();

end


--------------------------------------------------------------------------------

function on_spacing_changed()
  rebuild_pattern_data();
end


--------------------------------------------------------------------------------

function on_note_range_changed()
  rebuild_pattern_data();
end


--------------------------------------------------------------------------------

options.sections:add_notifier(on_sections_changed);
options.length:add_notifier(on_length_changed);
options.spacing:add_notifier(on_spacing_changed);
options.note_range_min:add_notifier(on_note_range_changed);
options.note_range_max:add_notifier(on_note_range_changed);


--------------------------------------------------------------------------------

function allow_opening_on_current_track()

  if (not renoise.song().selected_pattern_track.is_empty) then
    local answer = renoise.app():show_prompt(
      "Overwrite pattern data?",
      "Opening Tangram on a track that already contains data will delete " ..
      "all existing pattern data on that track.\n\nAre you sure you want to " ..
      "delete the existing content?",
      {"Yes", "No"});
    return answer == "Yes";
  end

  return true;

end


--------------------------------------------------------------------------------

function rebuild_pattern_data()
  renoise.song().selected_pattern_track:clear();

  renoise.song().selected_pattern.number_of_lines =
    options.length.value * options.spacing.value;

  for i = 1, options.length.value do
    write_note_from_scaled_value(i, knobs[i].value / 127);
  end
end


--------------------------------------------------------------------------------

function on_gui_knob_turned(step, value)
  write_note_from_scaled_value(step, value / 127);
  
  -- todo: set light on hw knob
end


--------------------------------------------------------------------------------

function on_midi_knob_turned(step, message)

  if (message:is_abs_value()) then

    if (step <= options.length.value) then
      write_note_from_scaled_value(step, message.int_value / 127);
      if (knobs[1] ~= nil) then
        knobs[step].value = message.int_value;
      end
    end
   
  elseif (message:is_rel_value()) then
    -- todo
  end

end


--------------------------------------------------------------------------------

function on_midi_transpose(offset, message)

  if (message:is_trigger()) then
    local instr = renoise.song().selected_instrument;

    for i = 1, #instr.samples do
      instr.samples[i].transpose = offset;
    end
    
    instr.plugin_properties.transpose = offset;

    instr.midi_output_properties.transpose = offset;
  end

end


--------------------------------------------------------------------------------

function on_midi_length_inced(message)

  print(message.int_value);

  if (options.length.value < MAX_STEPS) then
    options.length.value = options.length.value + 1;
  end
end


--------------------------------------------------------------------------------

function on_midi_length_deced(message)

  print(message.int_value);

  if (options.length.value > 1) then
    options.length.value = options.length.value - 1;
  end
end


--------------------------------------------------------------------------------

function on_midi_spacing_inced(message)
  if (options.spacing.value < MAX_SPACING) then
    options.spacing.value = options.spacing.value + 1
  end
end


--------------------------------------------------------------------------------

function on_midi_spacing_deced(message)
  if (options.spacing.value > 1) then
    options.spacing.value = options.spacing.value - 1
  end
end


--------------------------------------------------------------------------------

function on_new_document()

  renoise.tool().app_idle_observable:add_notifier(function()
    on_idle();
  end)
  
  renoise.song().transport.playing_observable:add_notifier(function()
    on_playing_changed();
  end)
  
end


--------------------------------------------------------------------------------

function on_playing_changed()
  if (knobs[1] ~= nil) then
    if (not renoise.song().transport.playing) then
      for i = 1, MAX_STEPS do
        knobs[i].active = true;
      end
    end
  end
end


--------------------------------------------------------------------------------

function on_idle()

  if (renoise.song().transport.playing) then

    local played_line = renoise.song().transport.playback_pos.line;

    if (played_line ~= last_played_line) then

      local length = options.length.value;
      local spacing = options.spacing.value;
      last_played_line = played_line;

      if ((last_played_line - 1) % spacing == 0) then

        local line_offset_from_start = (last_played_line - 1) % (length * spacing);
        local played_knob = (line_offset_from_start / spacing) + 1;
        
        if (knobs[1] ~= nil) then
          knobs[played_knob].active = false;
          
          if (played_knob > 1) then
            knobs[played_knob - 1].active = true;
          else
            knobs[length].active = true;
          end
          
          if (midi_out ~= nil) then
            -- ch11 cc81          
            -- 0xBB - a CC on ch11
            -- 0x51 - cc81 in hex
            -- 0x00 - value
            local midi_msg = { 0xBA, 0x51, 0x00 };
            midi_out:send(midi_msg);
          end

        end
        
      end
    end
  end

end


--------------------------------------------------------------------------------

function write_note_from_scaled_value(step, value)

  local note_min = options.note_range_min;
  local note_max = options.note_range_max;
  local note_range = note_max - note_min + 1;

  local note = math.floor((note_min - 1) + (value * note_range) + 0.5)

  if (note == (note_min - 1)) then
    note = 121;
  end

  local instr = (note == 121 and 255) or renoise.song().selected_instrument_index - 1;

  local line_idx = (step - 1) * options.spacing + 1;
  repeat
    local line = renoise.song().selected_pattern_track:line(line_idx);
    local note_col = line:note_column(1);
    
    note_col.note_value = note;
    note_col.instrument_value = instr;

    line_idx = line_idx + (options.length * options.spacing);
  until line_idx > renoise.song().selected_pattern.number_of_lines
    
  return note;

end
