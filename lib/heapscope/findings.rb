# frozen_string_literal: true

module HeapScope
  # Stable diagnostic codes. Each finding separates facts, derived behavior,
  # hypothesis, and suspected cause — never collapsed into fake certainty.
  module Diagnostics
    CODES = {
      "HS001" => {
        id: "HS001",
        name: "persistent_class_growth",
        title: "Persistent object population growth",
        default_severity: :medium
      },
      "HS002" => {
        id: "HS002",
        name: "high_retention_ratio",
        title: "High retention ratio after workload",
        default_severity: :high
      },
      "HS003" => {
        id: "HS003",
        name: "thread_local_retention",
        title: "Thread-local retention pattern",
        default_severity: :high
      },
      "HS004" => {
        id: "HS004",
        name: "unbounded_collection",
        title: "Unbounded collection growth candidate",
        default_severity: :high
      },
      "HS005" => {
        id: "HS005",
        name: "callback_accumulation",
        title: "Callback or subscriber accumulation",
        default_severity: :medium
      },
      "HS006" => {
        id: "HS006",
        name: "closure_retention",
        title: "Proc/closure retention candidate",
        default_severity: :medium
      },
      "HS007" => {
        id: "HS007",
        name: "poor_gc_recovery",
        title: "Poor recovery after forced GC",
        default_severity: :medium
      },
      "HS008" => {
        id: "HS008",
        name: "baseline_regression",
        title: "Memory retention regression vs baseline",
        default_severity: :high
      },
      "HS009" => {
        id: "HS009",
        name: "high_allocation_pressure",
        title: "High allocation pressure (churn)",
        default_severity: :low
      },
      "HS010" => {
        id: "HS010",
        name: "native_memory_mismatch",
        title: "RSS growth without matching Ruby heap growth",
        default_severity: :medium
      }
    }.freeze
  end

  # Ranking / dedupe helpers for findings lists.
  module Findings
    SEVERITY_WEIGHT = { high: 100, medium: 50, low: 10 }.freeze
    CODE_PRIORITY = {
      "HS002" => 20,
      "HS003" => 18,
      "HS004" => 18,
      "HS008" => 17,
      "HS001" => 15,
      "HS007" => 14,
      "HS005" => 12,
      "HS006" => 12,
      "HS010" => 10,
      "HS009" => 4
    }.freeze

    module_function

    def priority_score(finding)
      sev = SEVERITY_WEIGHT[finding.severity] || 0
      code = CODE_PRIORITY[finding.code] || 1
      sev + code
    end

    def rank_and_dedupe(findings)
      grouped = Array(findings).group_by { |f| [f.code, f.subject.to_s] }
      deduped = grouped.map do |_key, list|
        list.max_by { |f| priority_score(f) }
      end
      deduped.sort_by { |f| [-priority_score(f), f.code.to_s, f.subject.to_s] }
    end
  end

  class Finding
    attr_reader :code, :severity, :title, :facts, :derived, :hypothesis,
                :suspected_cause, :evidence, :suggestions, :subject

    def initialize(code:, severity:, title: nil, facts: [], derived: [],
                   hypothesis: nil, suspected_cause: nil, evidence: [],
                   suggestions: [], subject: nil)
      meta = Diagnostics::CODES[code] || {}
      @code = code
      @severity = severity || meta[:default_severity] || :low
      @title = title || meta[:title] || code
      @facts = Array(facts)
      @derived = Array(derived)
      @hypothesis = hypothesis
      @suspected_cause = suspected_cause
      @evidence = Array(evidence)
      @suggestions = Array(suggestions)
      @subject = subject
    end

    def name
      Diagnostics::CODES.dig(code, :name)
    end

    def priority
      Findings.priority_score(self)
    end

    def to_h
      {
        code: code,
        name: name,
        severity: severity.to_s,
        title: title,
        subject: subject,
        priority: priority,
        facts: facts,
        derived: derived,
        hypothesis: hypothesis,
        suspected_cause: suspected_cause,
        evidence: evidence,
        suggestions: suggestions
      }.compact
    end
  end
end
