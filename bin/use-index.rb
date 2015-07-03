#!/usr/bin/env ruby

require 'json'

GLOBAL = '/usr/portage/profiles/use.desc'
LOCAL  = '/usr/portage/profiles/use.local.desc'

output = { 'global' => {}, 'local' => {} }

File.readlines(GLOBAL).each do |line|
  next if line =~ /^(|#.*)$/

  flag, desc = line.strip.split(' - ', 2)
  output['global'][flag] = desc
end

File.readlines(LOCAL).each do |line|
  next if line =~ /^(|#.*)$/

  atom_flag, desc = line.strip.split(' - ', 2)
  atom, flag      = atom_flag.split(':', 2)
  cat, pkg        = atom.split('/', 2)

  output['local'][cat]          ||= {}
  output['local'][cat][pkg]     ||= {}
  output['local'][cat][pkg][flag] = desc
end

puts output.to_json
