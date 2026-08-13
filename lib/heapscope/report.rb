# frozen_string_literal: true

require "json"
require "time"

module HeapScope
  # Versioned report combining snapshots, diffs, findings, and presentation.
  class Report
    attr_reader :schema_version, :heapscope_version, :runtime_info, :summary,
                :before, :after, :diff, :findings, :suspects, :classes,
                :allocation_sites, :retention, :metadata, :limitations,
                :budget_result, :thread_locals, :reproduction,
                :fibers, :globals, :closures, :dominators, :fragmentation,
                :aging, :gc_correlation, :retention_paths

    def initialize(**attrs)
      @schema_version = attrs[:schema_version] || SCHEMA_VERSION
      @heapscope_version = attrs[:heapscope_version] || VERSION
      @runtime_info = attrs[:runtime_info] || {}
      @summary = attrs[:summary] || {}
      @before = attrs[:before]
      @after = attrs[:after]
      @diff = attrs[:diff]
      @findings = attrs[:findings] || []
      @suspects = attrs[:suspects] || []
      @classes = attrs[:classes] || []
      @allocation_sites = attrs[:allocation_sites] || []
      @retention = attrs[:retention]
      @metadata = attrs[:metadata] || {}
      @limitations = attrs[:limitations] || []
      @budget_result = attrs[:budget_result]
      @thread_locals = attrs[:thread_locals]
      @reproduction = attrs[:reproduction]
      @fibers = attrs[:fibers]
      @globals = attrs[:globals]
      @closures = attrs[:closures]
      @dominators = attrs[:dominators]
      @fragmentation = attrs[:fragmentation]
      @aging = attrs[:aging]
      @gc_correlation = attrs[:gc_correlation]
      @retention_paths = attrs[:retention_paths]
    end

    def healthy?
      summary[:healthy] == true || (findings.empty? && suspects.none? { |s| s[:severity] == :high })
    end

    def retained_count_for(klass)
      name = klass.is_a?(Module) ? klass.name : klass.to_s
      row = classes.find { |c| c[:name] == name || c["name"] == name }
      return row[:delta_count] || row["delta_count"] if row

      return 0 unless diff

      delta = diff.class_deltas.find { |c| c[:name] == name }
      delta ? delta[:delta_count] : 0
    end

    def retained_bytes_for(klass)
      name = klass.is_a?(Module) ? klass.name : klass.to_s
      return 0 unless diff

      delta = diff.class_deltas.find { |c| c[:name] == name }
      delta ? delta[:delta_bytes] : 0
    end

    def passed_budget?
      budget_result.nil? || budget_result[:passed]
    end

    def print(io = $stdout)
      io.puts to_text
      self
    end

    def to_s
      to_text
    end

    def to_text
      Report::Text.render(self)
    end

    def to_markdown
      Report::Markdown.render(self)
    end

    def save_markdown(path)
      File.write(path, to_markdown)
      path
    end

    def to_h
      {
        schema_version: schema_version,
        heapscope_version: heapscope_version,
        runtime: runtime_info,
        summary: summary,
        metadata: metadata,
        limitations: limitations,
        before: before&.to_h,
        after: after&.to_h,
        diff: diff_hash,
        classes: classes,
        allocation_sites: allocation_sites,
        findings: findings.map { |f| f.respond_to?(:to_h) ? f.to_h : f },
        suspects: suspects,
        retention: retention,
        budget_result: budget_result,
        thread_locals: thread_locals,
        reproduction: reproduction,
        fibers: fibers,
        globals: globals,
        closures: closures,
        dominators: dominators&.map { |d| d.respond_to?(:to_h) ? d.to_h : d },
        fragmentation: fragmentation,
        aging: aging,
        gc_correlation: gc_correlation,
        retention_paths: retention_paths
      }.compact
    end

    def to_json(*_args)
      JSON.pretty_generate(to_h)
    end

    def save(path)
      File.write(path, to_json)
      path
    end

    def scorecard(title: metadata[:title] || metadata["title"] || "HeapScope")
      Scorecard.from_report(self, title: title)
    end

    def table(format: :ascii)
      return "" unless diff

      Tables.class_growth(diff, format: format)
    end

    def findings_table(format: :ascii)
      Tables.findings(self, format: format)
    end

    def next_steps(limit: 8)
      Suggest.next_steps(self, limit: limit)
    end

    def ranked_findings
      Findings.rank_and_dedupe(findings)
    end

    def save_html(path)
      File.write(path, Report::HTML.render(self))
      path
    end

    def self.load(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      Schema.validate!(data)
      from_h(data)
    end

    def self.from_h(data)
      before = data[:before] ? Snapshot.from_h(data[:before]) : nil
      after = data[:after] ? Snapshot.from_h(data[:after]) : nil
      diff = before && after ? Diff.new(before, after) : nil
      findings = Array(data[:findings]).map do |f|
        Finding.new(
          code: f[:code],
          severity: f[:severity]&.to_sym,
          title: f[:title],
          facts: f[:facts],
          derived: f[:derived],
          hypothesis: f[:hypothesis],
          suspected_cause: f[:suspected_cause],
          evidence: f[:evidence],
          suggestions: f[:suggestions],
          subject: f[:subject]
        )
      end

      new(
        schema_version: data[:schema_version],
        heapscope_version: data[:heapscope_version],
        runtime_info: data[:runtime] || {},
        summary: data[:summary] || {},
        before: before,
        after: after,
        diff: diff,
        findings: findings,
        suspects: data[:suspects] || [],
        classes: data[:classes] || diff&.class_deltas || [],
        allocation_sites: data[:allocation_sites] || [],
        retention: data[:retention],
        metadata: data[:metadata] || {},
        limitations: data[:limitations] || [],
        budget_result: data[:budget_result],
        thread_locals: data[:thread_locals],
        reproduction: data[:reproduction],
        fibers: data[:fibers],
        globals: data[:globals],
        closures: data[:closures],
        dominators: data[:dominators],
        fragmentation: data[:fragmentation],
        aging: data[:aging],
        gc_correlation: data[:gc_correlation],
        retention_paths: data[:retention_paths]
      )
    end

    def self.from_diff(diff, analysis:, metadata: {})
      limitations = (diff.before.limitations + diff.after.limitations).uniq
      frag = Fragmentation.assess(diff.after)
      new(
        runtime_info: {
          ruby: RUBY_VERSION,
          engine: RUBY_ENGINE,
          platform: RUBY_PLATFORM
        },
        summary: analysis[:summary],
        before: diff.before,
        after: diff.after,
        diff: diff,
        findings: analysis[:findings],
        suspects: analysis[:suspects],
        classes: diff.class_deltas.sort_by { |c| -c[:delta_count].abs },
        allocation_sites: diff.allocation_deltas.first(50),
        fragmentation: frag,
        reproduction: {
          command: Reproduction.command(metadata),
          captured_at: Time.now.utc.iso8601
        },
        metadata: metadata,
        limitations: limitations
      )
    end

    def self.from_retention_session(session)
      analysis = Analyzer.new.analyze_retention(session)
      first = session.samples.first&.snapshot
      last = session.samples.last&.snapshot
      diff = first && last ? Diff.new(first, last) : nil
      diff_analysis = if diff
                        Analyzer.new.analyze_diff(diff,
                                                  context: { force_gc: session.force_gc })
                      else
                        { findings: [], suspects: [],
                          summary: {} }
                      end

      extras = Analyzer.new.enrich_session(session, last)
      all_findings = Findings.rank_and_dedupe(
        analysis[:findings] + diff_analysis[:findings] + Array(extras[:findings])
      )
      new(
        runtime_info: { ruby: RUBY_VERSION, engine: RUBY_ENGINE, platform: RUBY_PLATFORM },
        summary: analysis[:summary].merge(diff_analysis[:summary] || {}).merge(
          healthy: analysis[:persistent].empty? && all_findings.none? { |f| f.severity == :high }
        ),
        before: first,
        after: last,
        diff: diff,
        findings: all_findings,
        suspects: diff_analysis[:suspects],
        classes: diff&.class_deltas || [],
        retention: {
          samples: session.samples.size,
          force_gc: session.force_gc,
          persistent: analysis[:persistent].first(20),
          class_series: analysis[:class_series].values
                                               .select { |e| e[:delta].abs > 0 }
                                               .sort_by { |e| -e[:delta].abs }
                                               .first(50),
          collections: analysis[:collections]
        },
        thread_locals: analysis[:thread_locals],
        fibers: extras[:fibers],
        globals: extras[:globals],
        closures: extras[:closures],
        dominators: extras[:dominators],
        fragmentation: extras[:fragmentation],
        aging: extras[:aging],
        gc_correlation: extras[:gc_correlation],
        retention_paths: extras[:retention_paths],
        reproduction: {
          command: Reproduction.command(kind: "retention_test", cycles: session.samples.size),
          captured_at: Time.now.utc.iso8601
        },
        metadata: { kind: "retention_session" },
        limitations: [first, last].compact.flat_map(&:limitations).uniq + Array(extras[:limitations])
      )
    end

    private

    def diff_hash
      return nil unless diff

      diff.to_h
    end
  end
end

require_relative "report/text"
require_relative "report/html"
require_relative "report/markdown"
