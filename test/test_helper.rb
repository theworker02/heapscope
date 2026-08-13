# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "heapscope"
require "heapscope/minitest"
require "heapscope/cli"
require "tmpdir"
require "fileutils"
