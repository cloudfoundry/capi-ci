#!/usr/bin/env ruby

require "yaml"

blobs = YAML.load_file("config/blobs.yml")
package_specs = Dir["packages/**/*/**/spec"]

unused_blobs = blobs.dup

package_specs.each do |spec_path|
  spec = YAML.load_file(spec_path)

  spec["files"].each do |pattern|
    Dir.chdir("blobs") do
      Dir.glob(pattern, File::FNM_DOTMATCH).each do |blob|
        next if %w[. ..].include?(File.basename(blob))
        unused_blobs.delete(blob)
      end
    end
  end
end

unless unused_blobs.empty?
  puts "Unused blobs: #{unused_blobs.keys}"

  fail "Unused blobs exist"
end
