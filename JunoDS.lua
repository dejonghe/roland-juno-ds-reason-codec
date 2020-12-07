function remote_init(manufacturer, model)
	-- defining control surface items

	local items = {
		-- knobs
		{name="Knob 1", input="value", output="value", min=0, max=127},
		{name="Knob 2", input="value", output="value", min=0, max=127},
		{name="Knob 3", input="value", output="value", min=0, max=127},
		{name="Knob 4", input="value", output="value", min=0, max=127},
                -- faders
		{name="Fader 1", input="value", output="value", min=0, max=127},
		{name="Fader 2", input="value", output="value", min=0, max=127},
		{name="Fader 3", input="value", output="value", min=0, max=127},
		{name="Fader 4", input="value", output="value", min=0, max=127},
		-- pads
		{name="Pad 1", input="button", output="value"},
		{name="Pad 2", input="button", output="value"},
		{name="Pad 3", input="button", output="value"},
		{name="Pad 4", input="button", output="value"},
		{name="Pad 5", input="button", output="value"},
		{name="Pad 6", input="button", output="value"},
		{name="Pad 7", input="button", output="value"},
		{name="Pad 8", input="button", output="value"},

		-- control
		{name="Rewind", input="button", output="value"},
		{name="Play", input="button", output="value"},
		{name="Stop", input="button", output="value"},
		{name="Record", input="button", output="value"},

		{name="Keyboard", input="keyboard"},
		{name="Pitch Bend", input="value", min=0, max=16383},
		{name="Sustain", input="value", min=0, max=127},
	}

	remote.define_items(items)

	local inputs = {
		{pattern="B0 09 xx", name="Knob 1", port=1},
		{pattern="B0 0A xx", name="Knob 2", port=1},
		{pattern="B0 0B xx", name="Knob 3", port=1},
		{pattern="B0 0C xx", name="Knob 4", port=1},

		{pattern="B0 0B xx", name="Fader 1", port=1},
		{pattern="B0 0E xx", name="Fader 2", port=1},
		{pattern="B0 0F xx", name="Fader 3", port=1},
		{pattern="B0 10 xx", name="Fader 4", port=1},

		{pattern="90 36 xx", name="Pad 1", port=2},
		{pattern="90 37 xx", name="Pad 2", port=2},
		{pattern="90 38 xx", name="Pad 3", port=2},
		{pattern="90 39 xx", name="Pad 4", port=2},
		{pattern="90 3A xx", name="Pad 5", port=2},
		{pattern="90 3B xx", name="Pad 6", port=2},
		{pattern="90 3C xx", name="Pad 7", port=2},
		{pattern="90 3D xx", name="Pad 8", port=2},

		{pattern="90 5D ?<???x>", name="Rewind", port=2},
		{pattern="90 5D ?<???x>", name="Play", port=2},
		{pattern="90 5E ?<???x>", name="Stop", port=2},
		{pattern="90 5F ?<???x>", name="Record", port=2},

		{pattern="<100x>? yy zz", name="Keyboard", port=1},
		{pattern="e? xx yy", name="Pitch Bend", value="y*128 + x", port=1},
		{pattern="b? 40 xx", name="Sustain", port=1},
	}

	remote.define_auto_inputs(inputs)

	local outputs = {
		{name="Pad 1", pattern="90 60 0<00xx>", x="value*3"},
		{name="Pad 2", pattern="90 61 0<00xx>", x="value*3"},
		{name="Pad 3", pattern="90 62 0<00xx>", x="value*3"},
		{name="Pad 4", pattern="90 63 0<00xx>", x="value*3"},
		{name="Pad 5", pattern="90 64 0<00xx>", x="value*3"},
		{name="Pad 6", pattern="90 65 0<00xx>", x="value*3"},
		{name="Pad 7", pattern="90 66 0<00xx>", x="value*3"},
		{name="Pad 8", pattern="90 67 0<00xx>", x="value*3"},

		{name="Play", pattern="BF 73 xx", x="value*125+2"},
		{name="Record", pattern="BF 75 xx", x="value*125+2"},
	}
	remote.define_auto_outputs(outputs)

end

--[[
0 - Custom
1 - Volume
2 - Device
3 - Pan
4 - Send A
5 - Send B
]]--
g_knob_mode = 2 -- default is Device mode

--[[
0 - Custom
1 - Drum
2 - Session
]]--
g_pad_mode = 1 -- default id Drum mode

--[[
Shift status 0 or 127
]]--
g_shift_status = false

--[[
Pot/pickup
current values to compare with sended from control surface
]]--
g_knobs = {
	0, 0, 0, 0, 0, 0, 0, 0,
}

--[[
new_value - value sended from control surface
curr_value - value stored by remote into g_knobs
]]
function mute(new_value, curr_value)
	-- difference between values
	if new_value == curr_value or math.abs(new_value - curr_value) < 10 then
		return true
	else
		return false
	end
end

--[[
remote_set_state() is called regularly to update the state of control surface items.
changed_items is a table containing indexes to the items that have changed since the last call.
A common use for this function is useful to create a new “machine state”, mirroring the state of the whole control surface, at that point in time.
The new machine is later used to compare with a delivered machine state when remote_deliver_midi() is called.
]]
function remote_set_state(changed_items)
	-- update knobs state, set current values
	for i, item_index in ipairs(changed_items) do
		if item_index < 49 then
			local ki = item_index - g_knob_mode * 8
			g_knobs[ki] = remote.get_item_value(item_index)
		end
	end
end

--[[ listener
This function is called by Remote after an auto-input item message has been handled.
The typical use is to store the current time and item index, for timed feedback texts.
item_index is the index to the item.
]]--
function remote_on_auto_input(item_index)
	-- update knobs last value
	if item_index < 49 then
	local ki = item_index - g_knob_mode * 8
		g_knobs[ki] = remote.get_item_value(item_index)
	end
end

function remote_probe(manufacturer, model, prober)
	-- auto detect the surface

	local results = {}
	local port_out = 0
	local ins = {}
	local received_ports = {}
	local dev_found = 0
	local request_events={}
	local response = {}
	request_events = { remote.make_midi("F0 7E 7F 06 01 F7") }
	response = "F0 7E 00 06 02 00 20 29 02 01 00 00 ?? ?? ?? ?? F7"

	local function match_events(mask,events)
		for i,event in ipairs(events) do
			local res = remote.match_midi(mask,event)
			if res ~= nil then
				return true
			end
		end
		return false
	end

	-- check all the MIDI OUT ports
	for outPortIndex = 1, prober.out_ports do
		-- send device inquiry msg
		prober.midi_send_function(outPortIndex,request_events)
		prober.wait_function(50)

		-- check all the MIDI IN ports
		for inPortIndex = 1,prober.in_ports do
			local events = prober.midi_receive_function(inPortIndex)
			if match_events(response,events) then
				port_out = outPortIndex + 1         -- DAW port
				table.insert(ins, inPortIndex + 1)  -- DAW port
				table.insert(ins, inPortIndex)    -- MIDI port
				dev_found = dev_found + 1
				break
			end
		end
		if dev_found ~= 0 then
			break
		end
	end

	-- check a device has been found
	if dev_found ~= 0 then
		local one_result = { in_ports={ins[1], ins[2]}, out_ports={port_out} }
		table.insert(results, one_result)
	end

	return results
end

function remote_prepare_for_use()
	-- set device to 'DAW mode' and enter DRUM layout
	local retEvents = {
		remote.make_midi("9F 0C 7F"),
		remote.make_midi("BF 03 01"), -- PAD: DRUM LAYOUT
		remote.make_midi("BF 09 02"), -- KNOBS: DEVICE LAYOUT
	}
	return retEvents
end

function remote_release_from_use()
	-- set device to 'BASIC mode'
	local retEvents = {
		remote.make_midi("BF 03 00"),
		remote.make_midi("BF 09 00"),
		remote.make_midi("9F 0C 00"),
	}
	return retEvents
end

--[[
This function is called for each incoming MIDI event.
This is where the codec interprets the message and translates it into a Remote message.
The translated message is then passed back to Remote with a call to remote.handle_input().
If the event was translated and handled this function should return true, to indicate that the event was used.
If the function returns false, Remote will try to find a match using the automatic input registry defined with remote.define_auto_inputs().
]]--
function remote_process_midi(event)
	-- BF events:
	if event[1] == 191 then
		-- set pad mode
		if event[2] == 3 then
			g_pad_mode = event[3]
			-- use this event but not handle
			return true

		-- set knob mode
		elseif event[2] == 9 then
			g_knob_mode = event[3]
			-- use this event but not handle
			return true

		-- knob handler | BF 15 - BF 1C | knobe_mode 1 <> 5
		elseif event[2] >= 21 and event[2] <= 28 and not g_shift_status then
			local ki = event[2] - 20
			if mute(event[3], g_knobs[ki]) then
				g_knobs[ki] = event[3]
				-- knob_index 9 <> 40
				local knob_index = g_knob_mode * 8 + event[2] - 20
				remote.handle_input({time_stamp=event.time_stamp, item=knob_index, value=event[3]})
			end
			return true
		-- Shifted Play & Record
		elseif (event[2] == 115 or event[2] == 117) and g_shift_status then
			local button_index = 89
			if event[2] == 117 then
				button_index = 90
			end
			remote.handle_input({time_stamp=event.time_stamp, item=button_index, value=event[3]})
			return true
		end

	-- B0 events:
	elseif event[1] == 176 then
		if event[2] >= 21 and event[2] <= 28 and not g_shift_status then
			-- knob_index 1 <> 8
			local ki = event[2] - 20
			if mute(event[3], g_knobs[ki]) then
				g_knobs[ki] = event[3]
				remote.handle_input({time_stamp=event.time_stamp, item=ki, value=event[3]})
			end
			return true
		-- set shift status
		elseif event[2] == 108 then
			if event[3] == 0 then
				g_shift_status = false
			else
				g_shift_status = true
			end
			return true

		-- Shifted Cliplaunch 1/2
		elseif (event[2] == 104 or event[2] == 105) and g_shift_status then
			local button_index = event[2] - 19
			remote.handle_input({time_stamp=event.time_stamp, item=button_index, value=event[3]})
			return true
		end
	end

	return false
end
