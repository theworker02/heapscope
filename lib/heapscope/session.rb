# frozen_string_literal: true

require "fileutils"
require "json"
require "securerandom"
require "time"

module HeapScope
  # Named diagnostic sessions that persist artifacts under `.heapscope/`.
  class Session
    attr_reader :name, :dir, :id, :created_at, :reports

    def self.open(name, root: Dir.pwd)
      new(name, root: root).tap(&:ensure!)
    end

    def initialize(name, root: Dir.pwd)
      @name = name.to_s
      @id = SecureRandom.hex(4)
      @root = root
      @dir = File.join(root, ".heapscope", "sessions", sanitize(name))
      @created_at = Time.now.utc
      @reports = []
    end

    def ensure!
      FileUtils.mkdir_p(@dir)
      write_meta!
      self
    end

    def record(report, label: nil)
      label ||= "report-#{@reports.size + 1}"
      path = File.join(@dir, "#{label}.json")
      report.save(path)
      html = File.join(@dir, "#{label}.html")
      report.save_html(html)
      entry = { label: label, path: path, html: html, at: Time.now.utc.iso8601, healthy: report.healthy? }
      @reports << entry
      write_meta!
      entry
    end

    def measure(label: "measure", **opts, &block)
      report = HeapScope.measure(**opts, &block)
      record(report, label: label)
      report
    end

    def retention_test(label: "retention", **opts, &block)
      report = HeapScope.retention_test(**opts, &block)
      record(report, label: label)
      report
    end

    def latest
      @reports.last
    end

    def self.list(root: Dir.pwd)
      base = File.join(root, ".heapscope", "sessions")
      return [] unless Dir.exist?(base)

      Dir.children(base).sort.map do |name|
        meta_path = File.join(base, name, "meta.json")
        meta = File.exist?(meta_path) ? JSON.parse(File.read(meta_path), symbolize_names: true) : { name: name }
        meta
      end
    end

    private

    def sanitize(name)
      name.gsub(/[^a-zA-Z0-9_-]+/, "_")
    end

    def write_meta!
      File.write(
        File.join(@dir, "meta.json"),
        JSON.pretty_generate(
          name: @name,
          id: @id,
          created_at: @created_at.iso8601,
          reports: @reports,
          heapscope_version: VERSION
        )
      )
    end
  end
end
