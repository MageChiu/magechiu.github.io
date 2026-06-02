#!/usr/bin/env ruby
# frozen_string_literal: true

# 内容格式校验脚本
#
# 目的：在提交/构建之前，提前发现会导致页面显示异常的内容格式问题，
# 避免坏内容被合并后才在线上暴露（例如笔记因缺少 front matter 而被静默丢弃）。
#
# 校验范围：
#   - note/**/*.md      （专题笔记，index.md 只校验 YAML 合法性，不强制业务字段）
#   - _publications/*.md（论文元数据）
#
# 校验规则：
#   1. 必须存在 front matter 分隔块（--- ... ---）
#   2. front matter 必须是合法 YAML，且解析结果为非空 Hash
#   3. 必填字段必须存在且非空
#   4. date 字段必须可被解析为日期
#
# 用法：
#   ruby script/validate-content.rb          # 仅校验，发现问题以非零状态退出
#   ruby script/validate-content.rb --fix     # 先尝试自动修复 front matter 格式，再校验

require 'pathname'
require 'yaml'
require 'date'

REPO_ROOT = Pathname.new(File.expand_path('..', __dir__))

# 各类内容的必填字段
NOTE_REQUIRED_FIELDS = %w[title date summary].freeze
PUBLICATION_REQUIRED_FIELDS = %w[title collection category date venue paperurl authors].freeze

# front matter 分隔块。
# 注意：结束分隔符后只吞掉行内空白（[ \t]*），不吞掉正文换行，
# 否则重建内容时会误删正文开头的空行，造成无意义 diff。
FRONT_MATTER_REGEX = /\A---[ \t]*\n(.*?\n)---[ \t]*\n(.*)\z/m

FIX_MODE = ARGV.include?('--fix')

errors = []
warnings = []
fixed_files = []

# 收集待校验文件
def collect_targets
  notes = Dir.glob(REPO_ROOT.join('note', '**', '*.md')).sort
  pubs = Dir.glob(REPO_ROOT.join('_publications', '*.md')).sort
  { notes: notes, publications: pubs }
end

# 自动修复 front matter 内的格式问题：
#   - 去掉起始 --- 之后的空行
#   - 去掉结束 --- 之前的空行
#   - 去掉序列项（- xxx）之间/前后的空行
# 仅做空行规整，不改动字段内容与顺序，确保低风险。
def fix_front_matter(raw, body)
  lines = raw.split("\n", -1)

  # 去掉块首空行
  lines.shift while lines.first && lines.first.strip.empty?
  # 去掉块尾空行
  lines.pop while lines.last && lines.last.strip.empty?

  # 去掉 `key:` 与其后续序列项之间的空行，以及序列项之间的空行
  cleaned = []
  lines.each_with_index do |line, idx|
    if line.strip.empty?
      prev_line = cleaned.last
      next_line = lines[idx + 1]
      prev_is_list_context = prev_line && (prev_line.strip.start_with?('-') || prev_line.strip.end_with?(':'))
      next_is_list = next_line && next_line.strip.start_with?('-')
      next if prev_is_list_context && next_is_list
    end
    cleaned << line
  end

  "---\n#{cleaned.join("\n")}\n---\n#{body}"
end

def split_front_matter(content)
  return nil unless (m = content.match(FRONT_MATTER_REGEX))

  { raw: m[1], body: m[2] || '' }
end

def relative(path)
  Pathname.new(path).relative_path_from(REPO_ROOT).to_s
end

def validate_yaml(raw)
  parsed = YAML.safe_load(raw, permitted_classes: [Date, Time])
  return [nil, 'front matter 解析结果为空或不是键值结构'] unless parsed.is_a?(Hash) && !parsed.empty?

  [parsed, nil]
rescue StandardError => e
  [nil, "YAML 解析失败：#{e.message}"]
end

def validate_required(data, required_fields)
  missing = required_fields.reject do |field|
    value = data[field]
    !(value.nil? || (value.respond_to?(:empty?) && value.empty?))
  end
  missing
end

def validate_date(data)
  return nil unless data.key?('date')

  value = data['date']
  return nil if value.is_a?(Date) || value.is_a?(Time)

  Date.parse(value.to_s)
  nil
rescue StandardError
  "date 字段无法解析为日期：#{data['date'].inspect}"
end

targets = collect_targets

# ---------- 笔记 ----------
targets[:notes].each do |path|
  rel = relative(path)
  is_index = File.basename(path) == 'index.md'

  content = File.read(path, encoding: 'UTF-8')

  if FIX_MODE && (parts = split_front_matter(content))
    fixed = fix_front_matter(parts[:raw], parts[:body])
    if fixed != content
      File.write(path, fixed)
      fixed_files << rel
      content = fixed
    end
  end

  parts = split_front_matter(content)
  unless parts
    errors << "#{rel}: 缺少 front matter（--- ... --- 头部）"
    next
  end

  data, yaml_err = validate_yaml(parts[:raw])
  if yaml_err
    errors << "#{rel}: #{yaml_err}"
    next
  end

  # index.md 是专题页，由布局直接渲染，不强制业务字段
  next if is_index

  missing = validate_required(data, NOTE_REQUIRED_FIELDS)
  errors << "#{rel}: 缺少必填字段 #{missing.join(', ')}" unless missing.empty?

  if (date_err = validate_date(data))
    errors << "#{rel}: #{date_err}"
  end
end

# ---------- 论文 ----------
targets[:publications].each do |path|
  rel = relative(path)
  content = File.read(path, encoding: 'UTF-8')

  if FIX_MODE && (parts = split_front_matter(content))
    fixed = fix_front_matter(parts[:raw], parts[:body])
    if fixed != content
      File.write(path, fixed)
      fixed_files << rel
      content = fixed
    end
  end

  parts = split_front_matter(content)
  unless parts
    errors << "#{rel}: 缺少 front matter（--- ... --- 头部）"
    next
  end

  data, yaml_err = validate_yaml(parts[:raw])
  if yaml_err
    errors << "#{rel}: #{yaml_err}"
    next
  end

  missing = validate_required(data, PUBLICATION_REQUIRED_FIELDS)
  errors << "#{rel}: 缺少必填字段 #{missing.join(', ')}" unless missing.empty?

  if (date_err = validate_date(data))
    errors << "#{rel}: #{date_err}"
  end
end

# ---------- 输出 ----------
puts "[validate-content] 校验 #{targets[:notes].size} 篇笔记、#{targets[:publications].size} 篇论文"

unless fixed_files.empty?
  puts "\n[validate-content] 已自动修复 front matter 格式："
  fixed_files.each { |f| puts "  - #{f}" }
end

unless warnings.empty?
  puts "\n[validate-content] 警告："
  warnings.each { |w| puts "  ! #{w}" }
end

if errors.empty?
  puts "\n[validate-content] 通过：未发现会导致显示异常的格式问题。"
  exit 0
else
  puts "\n[validate-content] 失败：发现 #{errors.size} 个问题："
  errors.each { |e| puts "  x #{e}" }
  puts "\n提示：可运行 `ruby script/validate-content.rb --fix` 尝试自动修复 front matter 格式问题，字段缺失需手动补全。"
  exit 1
end
