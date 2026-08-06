# ─────────────────────────────────────────────────────────
#  REGISTER THE SCALE BRIDGE WITH THE XCODE TARGET
#
#  Copying a file into ios/Runner/ does not make Xcode build it.
#  Membership lives in project.pbxproj, which is normally edited
#  through the Xcode UI — and that needs a Mac.
#
#  This does the same thing from the command line, so a Windows
#  machine can drive the whole pipeline. It runs on the macOS build
#  runner before `pod install`.
#
#  Idempotent: adding a file that is already registered does nothing,
#  so it is safe on every build.
#
#  Usage, from the repository root:
#      ruby ios/add_qn_files.rb
#
#  The xcodeproj gem ships with CocoaPods, so it is already present on
#  any runner that installs pods.
# ─────────────────────────────────────────────────────────

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Runner.xcodeproj')
RUNNER_DIR   = File.join(__dir__, 'Runner')

# Swift sources get compiled; the .qn config is copied into the bundle.
SOURCES   = ['QnScalePlugin.swift']
RESOURCES = ['123456789.qn']

unless File.exist?(PROJECT_PATH)
  abort "Could not find #{PROJECT_PATH}"
end

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == 'Runner' }
abort 'No Runner target in the project' if target.nil?

group = project.main_group.find_subpath('Runner', true)

def already_referenced?(phase, name)
  phase.files_references.any? { |ref| ref && ref.path.to_s.end_with?(name) }
end

changed = false

SOURCES.each do |name|
  path = File.join(RUNNER_DIR, name)
  unless File.exist?(path)
    warn "SKIP  #{name} is not in ios/Runner — nothing to register"
    next
  end
  if already_referenced?(target.source_build_phase, name)
    puts "OK    #{name} already compiles"
    next
  end
  ref = group.new_reference(name)
  target.source_build_phase.add_file_reference(ref)
  puts "ADD   #{name} to Compile Sources"
  changed = true
end

RESOURCES.each do |name|
  path = File.join(RUNNER_DIR, name)
  unless File.exist?(path)
    # Worth shouting about: without the config file the SDK cannot
    # initialise, and the failure only shows at runtime.
    warn "SKIP  #{name} is not in ios/Runner — the scale SDK will not start"
    next
  end
  if already_referenced?(target.resources_build_phase, name)
    puts "OK    #{name} already bundled"
    next
  end
  ref = group.new_reference(name)
  target.resources_build_phase.add_file_reference(ref)
  puts "ADD   #{name} to Copy Bundle Resources"
  changed = true
end

if changed
  project.save
  puts 'Saved project.pbxproj'
else
  puts 'Nothing to change'
end
