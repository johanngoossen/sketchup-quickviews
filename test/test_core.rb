# Tests for the parts of Quick Views that do not need SketchUp.
# Run: ruby test/test_core.rb
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

# Minimal stand-in for the SketchUp preferences API.
module Sketchup
  @prefs = {}
  def self.read_default(section, key, default = nil)
    @prefs.fetch([section, key], default)
  end

  def self.write_default(section, key, value)
    @prefs[[section, key]] = value
  end

  def self.active_model
    nil
  end

  def self.get_locale
    'de-DE'
  end

  def self.reset_prefs
    @prefs = {}
  end
end

module JG
  module QuickViews
    PLUGIN_DIR = File.expand_path('../src/jg_quickviews', __dir__)
  end
end
QV = JG::QuickViews

%w[l10n presets filename_pattern frame_math].each { |f| require File.join(QV::PLUGIN_DIR, f) }

class FilenamePatternTest < Minitest::Test
  FP = QV::FilenamePattern
  TIME = Time.new(2026, 11, 1, 9, 5, 0)

  def ctx(extra = {})
    { nr: 3, scene: 'Ansicht Süd', model: 'Haus', time: TIME, preset: 'Full HD', width: 1920, height: 1080 }.merge(extra)
  end

  def test_default_pattern
    assert_equal '03_Ansicht Süd', FP.render('{nr}_{szene}', ctx)
  end

  def test_all_placeholders
    s = FP.render('{nr}-{szene}-{modell}-{datum}-{zeit}-{preset}-{breite}x{hoehe}', ctx)
    assert_equal '03-Ansicht Süd-Haus-261101-0905-Full HD-1920x1080', s
  end

def test_english_placeholders
  s = FP.render('{nr}-{scene}-{model}-{date}-{time}-{preset}-{width}x{height}', ctx)
  assert_equal '03-Ansicht Süd-Haus-261101-0905-Full HD-1920x1080', s
end

def test_default_pattern_follows_language
  assert_equal '{nr}_{scene}', FP.default_pattern('en')
  assert_equal '{nr}_{szene}', FP.default_pattern('de')
end

def test_unknown_placeholder_is_kept
    assert_equal '03_{foo}', FP.render('{nr}_{foo}', ctx)
  end

  def test_invalid_characters_replaced_spaces_kept
    assert_equal 'a_b_c_d_e_f_g_h_i_ j', FP.sanitize('a/b\\c:d*e?f"g<h>i| j')
  end

  def test_trailing_dots_and_empty
    assert_equal 'Szene', FP.sanitize(' ... ')
    assert_equal 'abc', FP.sanitize('abc. ')
  end

  def test_nr_three_digits
    assert_equal '120', FP.render('{nr}', ctx(nr: 120))
  end

  def test_allocator_duplicates_in_run
    Dir.mktmpdir do |dir|
      a = FP::Allocator.new(dir, 'png', existing: :overwrite)
      assert_equal File.join(dir, 'x.png'), a.allocate('x')
      assert_equal File.join(dir, 'x_2.png'), a.allocate('x')
      assert_equal File.join(dir, 'X_3.png'), a.allocate('X')
    end
  end

  def test_allocator_existing_files
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, 'x.png'))
      FileUtils.touch(File.join(dir, 'x_2.png'))
      assert_equal File.join(dir, 'x_3.png'), FP::Allocator.new(dir, 'png', existing: :suffix).allocate('x')
      assert_equal File.join(dir, 'x.png'), FP::Allocator.new(dir, 'png', existing: :overwrite).allocate('x')
    end
  end
end

class FrameMathTest < Minitest::Test
  FM = QV::FrameMath

  def assert_rect(expected, actual)
    expected.zip(actual).each { |e, a| assert_in_delta e, a, 1e-6 }
  end

  def test_wider_image_fills_width
    assert_rect [0, 75, 1600, 900], FM.frame_rect(1600, 1050, 1920, 1080)
  end

  def test_portrait_image_fills_height
    w = 1000 * 2480.0 / 3508
    assert_rect [(1600 - w) / 2, 0, w, 1000], FM.frame_rect(1600, 1000, 2480, 3508)
  end

  def test_camera_aspect_bars
    # camera aspect 2.0 in a 1000x1000 viewport -> visible 1000x500, square frame inside
    assert_rect [0, 250, 1000, 500], FM.visible_rect(1000, 1000, 2.0)
    assert_rect [250, 250, 500, 500], FM.frame_rect(1000, 1000, 1, 1, 2.0)
  end

  def test_shrink_factor_height_locked
    assert_in_delta 1.0, FM.shrink_factor(1.6, 1.0, true)
    assert_in_delta 1.6 / (16.0 / 9), FM.shrink_factor(1.6, 16.0 / 9, true)
  end

  def test_shrink_factor_width_locked
    assert_in_delta 1.0, FM.shrink_factor(1.6, 2.0, false)
    assert_in_delta 1.0 / 1.6, FM.shrink_factor(1.6, 1.0, false)
  end
end

class PresetsTest < Minitest::Test
  P = QV::Presets

  def setup
    Sketchup.reset_prefs
    QV::L10n.lang = 'de'
  end

  def test_builtins
    assert_equal 10, P.all.size
    assert_equal [3508, 2480], P.size_for(P.find('a4_landscape'))
    assert P.find('viewport')['viewport']
  end

  def test_builtin_protected
    assert_raises(ArgumentError) { P.delete('hd') }
    assert_raises(ArgumentError) { P.save(P.find('hd')) }
  end

  def test_user_preset_lifecycle
    copy = P.duplicate(P.find('hd'), 'Mein HD')
    refute copy['builtin']
    assert_equal 'Mein HD', P.find(copy['id'])['name']
    P.save(copy.merge('width' => 1000, 'format' => 'jpg', 'transparent' => true))
    stored = P.find(copy['id'])
    assert_equal 1000, stored['width']
    refute stored['transparent'], 'transparent only for png'
    P.rename(copy['id'], 'Neu')
    assert_equal 'Neu', P.find(copy['id'])['name']
    P.delete(copy['id'])
    assert_nil P.find(copy['id'])
  end

def test_builtin_names_localized
  assert_equal 'A4 quer, 300 dpi', P.find('a4_landscape')['name']
  QV::L10n.lang = 'en'
  assert_equal 'A4 landscape, 300 dpi', P.find('a4_landscape')['name']
  assert_equal 'Full HD', P.find('full_hd')['name']
end

def test_broken_json_is_ignored
    Sketchup.write_default('QuickViews', 'presets', '{kaputt')
    assert_equal 10, P.all.size
  end
end
