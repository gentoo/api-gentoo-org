#!/usr/bin/env ruby
# Generates projects.xml as per GLEP-67 from projects.json via semantic-data-toolkit.
# The file is only touched if contents change.
#
# Usage: projects-xml.rb <file>
#
# Alex Legler <a3li@gentoo.org>

require 'net/http'
require 'json'
require 'nokogiri'

PROJECTS_JSON = URI('https://wiki.gentoo.org/rdf/projects.json')

projects = begin
  JSON.parse(Net::HTTP.get(PROJECTS_JSON))
rescue JSON::ParserError
  abort 'Cannot load projects.json.'
end

parent_map = Hash.new { |h, k| h[k] = [] }

projects.each_pair do |id, project|
  parent_map[project['parent']] << id if project.key? 'parent'
end

projects_xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
  xml.doc.create_internal_subset('projects', nil, 'http://www.gentoo.org/dtd/projects.dtd')
  xml.projects do
    projects.each_pair do |id, project|
      xml.project do
        xml.email project['email']
        xml.name project['name']
        xml.url project['href']
        xml.description project['description']

        if parent_map.key? id
          parent_map[id].each do |subproject_id|
            attributes = { ref: projects[subproject_id]['email'] }
            attributes['inherit-members'] = '1' if projects[subproject_id]['propagates_members']

            xml.subproject nil, attributes
          end
        end

        project['members'].sort { |a, b| a['nickname'].casecmp(b['nickname']) }.each do |member|
          attributes = {}
          attributes['is-lead'] = '1' if member['is_lead']

          xml.member nil, attributes do
            xml.email member['email']
            xml.name member['name']
            xml.role member['role'] if member.key?('role') && !member['role'].empty?
          end
        end
      end
    end
  end
end

output_file = ARGV[0]

generated_xml = projects_xml.to_xml
current_xml = begin
  File.read(output_file)
rescue Errno::ENOENT
  ''
end

File.write(output_file, projects_xml.to_xml) unless generated_xml == current_xml
