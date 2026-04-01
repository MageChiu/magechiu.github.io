# frozen_string_literal: true

# Jekyll 自动内容识别插件
# 功能：
# 1. 自动扫描 note/ 目录，识别主题/分类，合并 _data/note_categories.yml 的元数据
# 2. 自动扫描 resources/papers/ 中的 PDF 文件，生成本地论文条目
# 3. 将本地论文与 _publications 集合合并，避免重复
# 4. 自动为主题生成虚拟页面数据（当主题没有物理 index.md 时）

require 'pathname'
require 'set'
require 'cgi'
require 'yaml'
require 'date'

module Jekyll
  # 自动内容识别生成器
  class AutoContentGenerator < Generator
    safe true
    priority :normal

    def generate(site)
      @site = site

      return if site.safe

      # 初始化数据存储
      site.data['auto_note_topics'] = {}
      site.data['auto_local_papers'] = []
      site.data['auto_merged_papers'] = []
      site.data['auto_virtual_topic_pages'] = []

      # 处理笔记目录
      process_notes

      # 处理本地论文
      process_local_papers

      filter_broken_local_publications

      # 生成合并后的论文列表
      generate_merged_papers

      Jekyll.logger.info 'AutoContent:', "Generated #{site.data['auto_note_topics'].size} note topics"
      Jekyll.logger.info 'AutoContent:', "Found #{site.data['auto_local_papers'].size} local PDF papers"
      Jekyll.logger.info 'AutoContent:', "Merged #{site.data['auto_merged_papers'].size} total papers"
    end

    private

    # ============================================
    # 笔记目录处理
    # ============================================

    def process_notes
      note_dir = Pathname.new(@site.source) / 'note'
      return unless note_dir.directory?

      # 扫描所有笔记文件
      note_files = scan_note_files(note_dir)

      # 按主题分组
      topics = group_notes_by_topic(note_files)

      # 合并元数据
      topics.each do |topic_key, notes|
        @site.data['auto_note_topics'][topic_key] = build_topic_data(topic_key, notes)
      end

      # 检测缺失物理 index.md 的主题，生成虚拟页面数据
      generate_virtual_topic_pages(topics.keys)
    end

    def scan_note_files(note_dir)
      notes = []
      config = load_note_config

      note_dir.children.each do |entry|
        next unless entry.directory?

        topic_key = entry.basename.to_s

        next if should_hide_topic?(topic_key, config)

        entry.children.sort.each do |md_file|
          next unless md_file.file? && md_file.extname.downcase == '.md'
          next if md_file.basename.to_s == 'index.md'

          relative_path = md_file.relative_path_from(Pathname.new(@site.source) / 'note').to_s
          next if should_hide_note?(relative_path, config)

          front_matter = read_front_matter(md_file)
          next unless front_matter

          notes << {
            'path' => md_file.relative_path_from(Pathname.new(@site.source)).to_s,
            'topic' => topic_key,
            'front_matter' => front_matter,
            'filename' => md_file.basename.to_s,
            'mtime' => md_file.mtime
          }
        end
      end

      notes
    end

    def load_note_config
      config = @site.data['note_config'] || {}
      Jekyll.logger.info 'AutoContent:', "Loaded note_config: #{config.inspect}"
      config
    end

    def should_hide_topic?(topic_key, config)
      hidden_topics = config['hidden_topics'] || []
      result = hidden_topics.include?(topic_key)
      Jekyll.logger.debug "AutoContent:", "Topic #{topic_key} hidden? #{result}" if result
      result
    end

    def should_hide_note?(relative_path, config)
      hidden_notes = config['hidden_notes'] || []
      result = hidden_notes.any? { |pattern| relative_path == pattern || File.fnmatch?(pattern, relative_path) }
      Jekyll.logger.info "AutoContent:", "Hiding note: #{relative_path}" if result
      result
    end

    # 读取文件的 front matter
    def read_front_matter(file_path)
      content = File.read(file_path, encoding: 'UTF-8')
      
      # 检查是否有 front matter
      if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
        yaml_content = $1
        begin
          YAML.safe_load(yaml_content, permitted_classes: [Date, Time]) || {}
        rescue => e
          Jekyll.logger.warn 'AutoContent:', "Failed to parse front matter in #{file_path}: #{e.message}"
          {}
        end
      else
        {}
      end
    end

    def group_notes_by_topic(note_files)
      topics = Hash.new { |h, k| h[k] = [] }

      note_files.each do |note|
        topic_key = note['front_matter']['section'] || note['topic']
        topics[topic_key] << note if topic_key
      end

      # 按日期倒序排序（统一转换为 Date 对象进行比较）
      topics.each do |_, notes|
        notes.sort_by! { |n| normalize_note_date(n) }.reverse!
      end

      topics
    end

    # 标准化笔记日期，统一转换为 Date 对象
    def normalize_note_date(note)
      date = note['front_matter']['date']
      return normalize_date(date) if date
      return normalize_date(note['mtime']) if note['mtime']
      Date.new(1970, 1, 1)
    end

    def build_topic_data(topic_key, notes)
      # 获取手动配置的元数据
      manual_meta = get_manual_topic_meta(topic_key)

      # 计算统计数据
      latest_note = notes.first
      note_count = notes.size

      # 收集所有标签
      all_tags = notes.flat_map { |n| n['front_matter']['tags'] || [] }.uniq.sort

      {
        'key' => topic_key,
        'title' => manual_meta['title'] || humanize_topic_key(topic_key),
        'description' => manual_meta['description'] || "#{topic_key} 主题的技术笔记集合。",
        'note_count' => note_count,
        'latest_note' => latest_note ? note_to_summary(latest_note) : nil,
        'notes' => notes.map { |n| note_to_summary(n) },
        'tags' => all_tags,
        'has_physical_index' => physical_index_exists?(topic_key),
        'manual_meta' => manual_meta
      }
    end

    def note_to_summary(note)
      fm = note['front_matter']
      {
        'title' => fm['title'] || 'Untitled',
        'date' => fm['date'],
        'summary' => fm['summary'],
        'tags' => fm['tags'] || [],
        'path' => note['path'],
        'filename' => note['filename']
      }
    end

    def get_manual_topic_meta(topic_key)
      return {} unless @site.data['note_categories']

      @site.data['note_categories'].find { |c| c['key'] == topic_key } || {}
    end

    def physical_index_exists?(topic_key)
      index_path = Pathname.new(@site.source) / 'note' / topic_key / 'index.md'
      index_path.file?
    end

    def humanize_topic_key(topic_key)
      topic_key.to_s
               .gsub(/[_-]+/, ' ')
               .split
               .map(&:capitalize)
               .join(' ')
    end

    def generate_virtual_topic_pages(topic_keys)
      topic_keys.each do |topic_key|
        next if physical_index_exists?(topic_key)

        topic_data = @site.data['auto_note_topics'][topic_key]
        next unless topic_data

        # 生成虚拟页面数据，供布局使用
        @site.data['auto_virtual_topic_pages'] << {
          'path' => "note/#{topic_key}/index.md",
          'url' => "/note/#{topic_key}/",
          'topic_key' => topic_key,
          'title' => topic_data['title'],
          'description' => topic_data['description'],
          'note_count' => topic_data['note_count'],
          'is_virtual' => true
        }
      end
    end

    # ============================================
    # 本地论文处理
    # ============================================

    def process_local_papers
      papers_dir = Pathname.new(@site.source) / 'resources' / 'papers'
      return unless papers_dir.directory?

      # 获取已存在的 publication 中引用的本地 PDF 路径
      existing_local_pdfs = collect_existing_local_pdfs

      # 扫描 PDF 文件
      papers_dir.children.sort.each do |pdf_file|
        next unless pdf_file.file? && pdf_file.extname.downcase == '.pdf'

        pdf_name = pdf_file.basename.to_s
        pdf_path = '/resources/papers/' + pdf_name

        # 跳过已存在于 _publications 中的 PDF
        next if normalize_pdf_reference(pdf_path).any? { |variant| existing_local_pdfs.include?(variant) }

        # 生成本地论文数据
        paper_data = build_local_paper_data(pdf_file, pdf_path)
        @site.data['auto_local_papers'] << paper_data
      end

      # 按文件名排序
      @site.data['auto_local_papers'].sort_by! { |p| p['filename'] }.reverse!
    end

    def collect_existing_local_pdfs
      pdfs = Set.new

      return pdfs unless @site.collections.key?('publications')

      @site.collections['publications'].docs.each do |doc|
        paperurl = doc.data['paperurl']
        next unless paperurl

        # 检查是否指向本地 PDF
        if paperurl.include?('/resources/papers/') || paperurl.end_with?('.pdf')
          normalize_pdf_reference(paperurl).each do |variant|
            pdfs << variant
          end
        end
      end

      pdfs
    end

    def normalize_pdf_reference(reference)
      raw = reference.to_s.split('?').first
      decoded = CGI.unescape(raw)

      [
        raw,
        decoded,
        File.basename(raw),
        File.basename(decoded)
      ].reject(&:empty?).uniq
    end

    def build_local_paper_data(pdf_file, pdf_path)
      filename = pdf_file.basename.to_s
      # 移除 .pdf 扩展名
      base_name = filename.gsub(/\.pdf$/i, '')

      # 生成友好的标题
      title = humanize_filename(base_name)

      # 提取年份（从文件名中尝试提取）
      year = extract_year_from_filename(base_name) || pdf_file.mtime.year

      # 生成唯一 ID
      paper_id = generate_paper_id(base_name)

      {
        'id' => paper_id,
        'title' => title,
        'filename' => filename,
        'pdf_path' => pdf_path,
        'year' => year,
        'date' => Date.new(year, 1, 1),
        'authors' => 'Archived material',
        'venue' => 'Local Archive',
        'category' => 'local-files',
        'paper_source' => 'local',
        'excerpt' => '本地归档的论文资料，可通过站点直接访问。',
        'tags' => ['local-pdf', 'auto-generated'],
        'featured' => false,
        'auto_generated' => true,
        'mtime' => pdf_file.mtime
      }
    end

    def humanize_filename(filename)
      # 将文件名转换为可读标题
      # 替换下划线和连字符为空格，处理驼峰等
      title = filename
                .gsub(/[_-]+/, ' ')
                .gsub(/([a-z])([A-Z])/, '\1 \2')
                .gsub(/\s+/, ' ')
                .strip

      # 如果是纯数字或编号格式，使用更通用的标题
      if title =~ /^\d+(\.\d+)*$/
        "Archived Paper #{title}"
      else
        title
      end
    end

    def extract_year_from_filename(filename)
      # 尝试从文件名中提取年份 (19xx-20xx)
      if filename =~ /(19|20)\d{2}/
        $&.to_i
      else
        nil
      end
    end

    def generate_paper_id(base_name)
      # 生成 URL 友好的 ID
      base_name.downcase
                .gsub(/[^a-z0-9]+/, '-')
                .gsub(/^-+|-+$/, '')
                .slice(0, 50)
    end

    # ============================================
    # 合并论文列表
    # ============================================

    def filter_broken_local_publications
      return unless @site.collections.key?('publications')

      valid_docs = []

      @site.collections['publications'].docs.each do |doc|
        local_file_exists = local_paper_file_exists?(doc.data['paperurl'], doc.data['paper_source'])
        doc.data['local_file_exists'] = local_file_exists
        doc.data['broken_local_file'] = doc.data['paper_source'] == 'local' && !local_file_exists

        if doc.data['broken_local_file']
          Jekyll.logger.warn 'AutoContent:', "Skipping missing local paper: #{doc.relative_path} -> #{doc.data['paperurl']}"
          next
        end

        valid_docs << doc
      end

      @site.collections['publications'].docs.replace(valid_docs)
      @site.pages.reject! do |page|
        next false unless page.respond_to?(:collection) && page.collection

        page.collection.label == 'publications' && page.data['paper_source'] == 'local' && page.data['broken_local_file'] == true
      end
    end

    def generate_merged_papers
      merged = []

      # 添加现有的 publications
      if @site.collections.key?('publications')
        @site.collections['publications'].docs.each do |doc|
          merged << doc_to_paper_hash(doc)
        end
      end

      # 添加自动生成的本地论文
      @site.data['auto_local_papers'].each do |local_paper|
        merged << local_paper
      end

      # 按日期倒序排序（统一转换为 Date 对象进行比较）
      merged.sort_by! { |p| normalize_date(p['date']) || Date.new(1970, 1, 1) }.reverse!

      @site.data['auto_merged_papers'] = merged
    end

    # 将各种日期格式统一转换为 Date 对象
    def normalize_date(date)
      return nil if date.nil?
      return date.to_date if date.respond_to?(:to_date)
      return date if date.is_a?(Date)
      Date.parse(date.to_s) rescue nil
    end

    def doc_to_paper_hash(doc)
      paperurl = doc.data['paperurl']
      paper_source = doc.data['paper_source']
      local_file_exists = local_paper_file_exists?(paperurl, paper_source)

      {
        'id' => doc.basename_without_ext,
        'title' => doc.data['title'],
        'date' => doc.data['date'],
        'year' => doc.data['year'] || doc.data['date']&.year,
        'authors' => doc.data['authors'],
        'venue' => doc.data['venue'],
        'category' => doc.data['category'],
        'paperurl' => paperurl,
        'paper_source' => paper_source,
        'excerpt' => doc.data['excerpt'] || doc.data['summary'],
        'summary' => doc.data['summary'],
        'citation' => doc.data['citation'],
        'tags' => doc.data['tags'] || [],
        'featured' => doc.data['featured'] || false,
        'url' => doc.url,
        'local_file_exists' => local_file_exists,
        'broken_local_file' => paper_source == 'local' && !local_file_exists,
        'doc' => doc,
        'auto_generated' => false
      }
    end

    def local_paper_file_exists?(paperurl, paper_source)
      return true unless paper_source == 'local'
      return false if paperurl.nil? || paperurl.to_s.strip.empty?

      normalized_path = CGI.unescape(paperurl.to_s.split('?').first)
      relative_path = normalized_path.sub(%r{^/}, '')
      file_path = Pathname.new(@site.source) / relative_path

      file_path.file?
    end
  end

  # ============================================
  # 过滤器增强
  # ============================================

  module AutoContentFilters
    # 检查主题是否为虚拟主题（没有物理 index.md）
    def virtual_topic?(topic_key)
      return false unless topic_key

      topics = @context.registers[:site].data['auto_note_topics']
      return false unless topics

      topic = topics[topic_key]
      topic && !topic['has_physical_index']
    end

    # 获取自动生成的主题数据
    def auto_topic_data(topic_key)
      topics = @context.registers[:site].data['auto_note_topics']
      return nil unless topics

      topics[topic_key]
    end

    # 检查论文是否为自动生成
    def auto_generated_paper?(paper)
      paper && paper['auto_generated'] == true
    end

    # 获取合并后的论文列表
    def merged_papers
      @context.registers[:site].data['auto_merged_papers'] || []
    end

    # 按类别过滤合并后的论文
    def papers_by_category(category)
      merged_papers.select { |p| p['category'] == category }
    end

    # 获取所有主题（包括虚拟主题）
    def all_topics
      topics = @context.registers[:site].data['auto_note_topics'] || {}
      topics.values
    end

    # 获取带物理页面的主题
    def physical_topics
      all_topics.select { |t| t['has_physical_index'] }
    end

    # 获取虚拟主题
    def virtual_topics
      all_topics.reject { |t| t['has_physical_index'] }
    end
  end

  # ============================================
  # 虚拟主题页面生成器（使用 pages）
  # ============================================

  class VirtualTopicPageGenerator < Generator
    safe true
    priority :low

    def generate(site)
      @site = site

      return if site.safe

      virtual_pages = site.data['auto_virtual_topic_pages'] || []

      virtual_pages.each do |page_data|
        generate_virtual_page(page_data)
      end
    end

    private

    def generate_virtual_page(page_data)
      # 创建虚拟页面
      page = VirtualTopicPage.new(
        @site,
        @site.source,
        page_data['topic_key'],
        page_data
      )

      @site.pages << page
      Jekyll.logger.debug 'AutoContent:', "Generated virtual page for topic: #{page_data['topic_key']}"
    end
  end

  # 虚拟主题页面类
  class VirtualTopicPage < PageWithoutAFile
    def initialize(site, base, topic_key, page_data)
      @site = site
      @base = base

      super(site, base, "note/#{topic_key}", 'index.html')

      data.default_proc = proc do |_, key|
        site.frontmatter_defaults.find(relative_path, :pages, key)
      end

      data['layout'] = 'note_topic'
      data['title'] = page_data['title']
      data['description'] = page_data['description']
      data['note_category'] = topic_key
      data['is_virtual_topic'] = true
      data['permalink'] = "/note/#{topic_key}/"

      self.content = generate_content(page_data)
    end

    private

    def generate_content(page_data)
      <<~CONTENT
        <!-- 自动生成的主题页面内容 -->
        <p>这是 <strong>#{page_data['title']}</strong> 主题的笔记集合页，包含 #{page_data['note_count']} 篇笔记。</p>

        <p>此页面由系统自动生成，无需手动维护。</p>
      CONTENT
    end
  end
end

# 注册过滤器
Liquid::Template.register_filter(Jekyll::AutoContentFilters)
