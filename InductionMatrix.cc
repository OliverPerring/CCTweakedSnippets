--[[
  Wolfe's Mekanism Induction Matrix Monitor v2 (Receiver Module)
  Usage: Put computer near Modem and Monitor (2x3 array should work fine) and install. Requires another computer transmitting matrix data over rednet to work.
  Installation: pastebin run 3naSaR8X install
  Configuration: Edit the "config" file, refer to the comments below for what each field means
]]

-- Default settings, do not change
local options = {
  -- Unique identifier for the destination matrix on rednet
  rednet_identifier = '',

  -- Energy type being displayed (J, FE)
  energy_type = 'FE',

  -- Text scale on the monitor
  text_scale = 1,

  -- Output debug data to the computer's internal display
  debug = true,
}

--------------------------------------------------
--- Internal variables, DO NOT CHANGE
--------------------------------------------------

--- This will be used as the installer source (Pastebin)
local INSTALLER_ID = '3naSaR8X'

--- Supported energy suffixes
local energy_suffixes = { 'k', 'M', 'G', 'T', 'P' }

--- Supported time periods when converting seconds
local time_periods = {
  { 'weeks', 604800 },
  { 'days', 86400 },
  { 'hours', 3600 },
  { 'minutes', 60 },
  { 'seconds', 1 },
}

--- This is our Induction Matrix, we'll auto-detect it later
local induction_matrix = nil

--- This is our Monitor, we'll auto-detect it later
local monitor = nil

--- This is our Modem, we'll auto-detect it later
local modem = nil

--- Prefix used for rednet channels
local rednet_prefix = 'WL_Mek_Matrix'

--------------------------------------------------
--- Helper functions
--------------------------------------------------

--- Reads a file's contents
---@return string
function file_read (file)
  local handle = fs.open(file, 'r')
  local data = handle.readAll()
  handle.close()
  return data
end

--- Writes data to a file (overrides existing data)
function file_write (file, data)
  local handle = fs.open(file, 'w')
  handle.write(data)
  handle.close()
end

--- Holds the current buffer of data being printed
local machine_term = term.current()
local print_buffer = {}

--- Writes data to the output monitor buffer
function print_r (text)
  table.insert(print_buffer, text)
end

--- Writes formatted data to the output monitor buffer
function print_f (format, ...)
  print_r(string.format(format, ...))
end

--- Writes the buffer into the output monitor
function print_flush ()
  -- Redirects writes to monitor (if any)
  term.redirect(monitor)

  -- Clears terminal
  term.clear()
  term.setCursorPos(1, 1)

  -- Writes new data
  print(table.concat(print_buffer or {}, '\n'))

  -- Redirects writes back to computer (if using monitor)
  term.redirect(machine_term)

  -- Clears buffer
  print_buffer = {}
end

--- Writes debug info to the machine
function debug (...)
  if options.debug then
    print(...)
  end
end

--- Rounds a number with N decimals
function round_decimal (number, decimals)
  local multiplier = math.pow(10, decimals or 0)
  return math.floor(number * multiplier) / multiplier
end

--- Rounds a percentage (0..1) to a number of decimals
function round_percentage (number, decimals)
  return ('%s%%'):format(round_decimal(100 * number, decimals or 1))
end

--- The current energy type
local energy_type = 'J'

--- Converts energy values
local energy_convert = function (energy) return energy end
if mekanismEnergyHelper and mekanismEnergyHelper[('joulesTo%s'):format(options.energy_type)] then
  energy_type = options.energy_type
  energy_convert = mekanismEnergyHelper[('joulesTo%s'):format(options.energy_type)]
end

--- Prints an energy value
local energy_string = function (energy, decimals)
  local prefix = ''
  local suffix = ''

  -- Prepares a prefix for negative numbers
  if energy < 0 then
    prefix = '-'
  end

  -- We need a positive number here for calculating multipliers (k, M, G, T), we'll add the minus later, we also convert it to the right unit
  local amount = energy_convert(math.abs(energy))

  -- Finds the proper suffix/multiplier
  for _, multiplier in pairs(energy_suffixes) do
    -- Stops when amount is less than 1000
    if amount < 1000 then
      break
    end

    -- Updates suffix and amount to new value
    amount = amount / 1000
    suffix = multiplier
  end

  -- Returns the formatted string
  return ('%s%s%s%s'):format(prefix, round_decimal(amount, decimals or 1), suffix, energy_type)
end

--- Generates an ETA string when given a number of seconds
function eta_string (seconds)
  -- Makes sure we're only dealing with integers
  seconds = math.floor(seconds)

  -- Processes time periods
  local time = {}
  for _, period in pairs(time_periods) do
    local count = math.floor(seconds / period[2])
    time[period[1]] = count
    seconds = seconds - (count * period[2])
  end

  -- If we have more than 72h worth of storage, switch to week, day, hour format
  if time.weeks > 0 then
    return ('%dwk %dd %dh'):format(time.weeks, time.days, time.hours)
  elseif time.days >= 3 then
    return ('%dd %dh'):format(time.days, time.hours)
  end

  -- For all other cases, we'll just use H:MM:SS
  return ('%d:%02d:%02d'):format(time.hours, time.minutes, time.seconds)
end

--- Prints the Induction Matrix information
function print_matrix_info (matrix_info)
  print_r('Ind.Matrix Monitor')
  print_r('------------------')
  print_r('')
  print_f('Power : %s', energy_string(matrix_info.energy_stored))
  print_f('Limit : %s', energy_string(matrix_info.energy_capacity))
  print_f('Charge: %s', round_percentage(matrix_info.energy_percentage))
  print_r('')
  print_f('Input : %s/t', energy_string(matrix_info.io_input))
  print_f('Output: %s/t', energy_string(matrix_info.io_output))
  print_f('Max IO: %s/t', energy_string(matrix_info.io_capacity))
  print_r('')

  -- If we have negative value here, we'll save a character by removing the space so it fits same line
  if matrix_info.change_amount < 0 then
    print_f('Change:%s/s', energy_string(matrix_info.change_amount_per_second))
  else
    print_f('Change: %s/s', energy_string(matrix_info.change_amount_per_second))
  end

  -- Charge/discharge status
  print_r('Status:')
  if matrix_info.is_charging then
    print_f('Charg. %s', eta_string((matrix_info.energy_capacity - matrix_info.energy_stored) / matrix_info.change_amount_per_second))
  elseif matrix_info.is_discharging then
    print_f('Disch. %s', eta_string(matrix_info.energy_stored / math.abs(matrix_info.change_amount_per_second)))
  else
    print_r('Idle')
  end
end

--------------------------------------------------
--- Program initialization
--------------------------------------------------

args = {...}

-- Loads custom options from filesystem
if fs.exists('config') then
  debug('Loading settings from "config" file...')

  -- Reads custom options
  local custom_options = textutils.unserialize(file_read('config'))

  -- Overrides each of the existing options
  for k, v in pairs(custom_options) do
    options[k] = v
  end
end

-- Writes back config file
print('Updating config file...')
file_write('config', textutils.serialize(options))

-- Handles special case when "install" is executed from the pastebin
if 'install' == args[1] then
  print('Installing Matrix Monitor (Receiver Module)...')

  -- Are we on first install? If so, we'll run open the config for editing later
  local has_existing_install = fs.exists('startup.lua')

  -- Removes existing version
  if fs.exists('startup.lua') then
    fs.delete('startup.lua')
  end

  -- Downloads script from Pastebin
  shell.run('pastebin', 'get', INSTALLER_ID, 'startup.lua')

  -- Runs config editor
  if not has_existing_install then
    print('Opening config file for editing...')
    sleep(2.5)
    shell.run('edit', 'config')
  end

  -- Reboots the computer after everything is done
  print('Install complete! Restarting computer...')
  sleep(2.5)
  os.reboot()
end

-- Detects peripherals
monitor = peripheral.find('monitor')
modem = peripheral.find('modem')

--- The rednet channel/protocol we'll be using
local rednet_channel = nil

-- Makes sure we have a connected monitor
if monitor then
  monitor.setTextScale(options.text_scale)
else
  error('No monitor detected!')
end

-- Makes sure we have a connected modem
if modem then
  if not options.rednet_identifier or options.rednet_identifier == '' then
    error('Modem has been found, but no wireless identifier found on configs!')
  end

  peripheral.find('modem', rednet.open)
  debug('Connected to rednet!')
  rednet_channel = ('%s#%s'):format(rednet_prefix, options.rednet_identifier)
else
  error('No modem detected!')
end

--------------------------------------------------
--- Main runtime
--------------------------------------------------

debug('Entering main loop...')

while true do
  -- Receives next update
  local id, message = rednet.receive(rednet_channel)

  -- Parses message
  local matrix_info = textutils.unserialize(message)

  -- Prints the matrix information
  print_matrix_info(matrix_info)

  -- Outputs text to screen
  print_flush()
end
