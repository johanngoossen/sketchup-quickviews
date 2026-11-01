# Quick Views – batch export of SketchUp scenes as images.
# Loader file: registers the extension; the code lives in jg_quickviews/.
#
# Author: Johann Gooßen – https://johanngoossen.com
# License: MIT

require 'sketchup.rb'
require 'extensions.rb'

module JG
  module QuickViews
    NAME = 'Quick Views'.freeze
    VERSION = '0.1.0'.freeze
    PLUGIN_DIR = File.join(File.dirname(__FILE__), 'jg_quickviews').freeze

    require File.join(PLUGIN_DIR, 'l10n')

    unless file_loaded?(__FILE__)
      ext = SketchupExtension.new(NAME, File.join(PLUGIN_DIR, 'main'))
      ext.description = L10n.t('ext.description')
      ext.version = VERSION
      ext.creator = 'Johann Gooßen'
      ext.copyright = "© #{Time.now.year} Johann Gooßen"
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
