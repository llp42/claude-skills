#!/usr/bin/env bash

jq -r '
  def fmt_k: (. // 0) / 1000 | floor | "\(.)K";

  def gray: "[38;5;248m";

  # seconds -> compact duration
  def dur:
    (. // 0) | floor |
    if   . <= 0    then "now"
    elif . < 3600  then "\(. / 60 | floor)m"
    elif . < 86400 then "\(. / 3600 | floor)h\((. % 3600) / 60 | floor)m"
    else                "\(. / 86400 | floor)d\((. % 86400) / 3600 | floor)h"
    end;

  def pct_color:
    if   . >= 90 then "[38;5;203m"   # red
    elif . >= 70 then "[38;5;179m"   # yellow
    else              ""
    end;

  # one rate-limit bucket: "5h 24% (3h53m left)"
  def bucket($lbl):
    if . == null or .used_percentage == null then empty
    else
      (.used_percentage | round) as $p
      | (.resets_at // 0) as $r
      | $lbl + " " + ($p | pct_color) + "\($p)%" + gray
        + (if $r > 0 then " (\(($r - now) | dur) left)" else "" end)
    end;

  gray + (
    [
      # 1. Session Name
      (.session_name // .session_id // "Unnamed Session"),

      # 2. Model
      (
        [
          .model?.display_name,
          .effort?.level,
          (if .thinking?.enabled then "thinking" else null end)
        ]
        | map(select(. != null and . != ""))
        | if length > 0 then join (" - ") else null end
      ),

      # 3. Diff
      "Diff: +\((.cost?.total_lines_added // 0))/-\((.cost?.total_lines_removed // 0))",

      # 4. Cost
      "Cost: $\((.cost?.total_cost_usd // 0) * 100 | round / 100)",

      # 5. Context
      "Ctx: \((.context_window?.total_input_tokens | fmt_k))/\((.context_window?.context_window_size | fmt_k)) (\((.context_window?.current_usage?.cache_read_input_tokens | fmt_k)) Cached)",

      # 6. Subscription usage
      (
        [
          (.rate_limits?.five_hour      | bucket("5h")),
          (.rate_limits?.seven_day      | bucket("7d")),
          (.rate_limits?.seven_day_opus | bucket("7d opus"))
        ]
        | map(select(. != null and . != ""))
        | if length > 0 then join(" · ") else null end
      )
    ]
    | map(select(. != null and . != ""))
    | join(" | ")
    ) + "[0m"
'
