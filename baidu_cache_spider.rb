#coding: utf-8
require 'nokogiri'
require 'open-uri'

# 我要抓取的地址，不能有http
@my_url = "rubyer.me"
# 所有快照源码存放的路径
@path = "./rubyer_cache"


def log(str)
  File.open("info.txt", "w+") {|f| f.puts str}
end

BAIDU_CACHE_URL = "http://www.baidu.com/s?wd=site:%s"
BAIDU_CACHE_PAGE_URL = "http://www.baidu.com/s?wd=site:%s?&pn=%d"

# 根据url得到网页源码
def get_source(url)
  #sleep for a while or baidu will block you
  log "sleep for:" + sleep(rand 5).to_s
  begin
    html = open(url).read
    html.force_encoding("gbk")
    html.encode!("utf-8", :undef => :replace, :replace => "?", :invalid => :replace)
    Nokogiri::HTML.parse html
  rescue Exception => e
    puts "Error url: #{url}"
    puts e.message
    puts e.backtrace.inspect
  end
end

# 抓取第page_num页的源码
def get_source_of_baidu_page(page_num)
  url = BAIDU_CACHE_PAGE_URL % [@my_url, page_num]
  get_source(url)
end

# 从百度快照源码抽取出有用的信息，其实这就是原始网站源码
def get_cache(source_html)
  if source_html && source_html.xpath("/html/body/div[3]")[0]
    source_html.xpath("/html/body/div[3]")[0].inner_html
  else
    #有一些页面快照结构有问题，打出来，手工分析
    log "===============get cache error occurs next==================================="
    log source_html
    log "===============get cache error occurs above=================================="
  end
end

# 获取百度快照的所有页面
def get_all_baidu_cache_pages
  doc = get_source(BAIDU_CACHE_URL % @my_url)
  total_num = doc.css(".site_tip strong")[0].content.scan(/\d+/)[0].to_i
  pages = []
  pages << doc.css("#container .result")
  i = 1
  while i*10 < total_num do
    doc = get_source_of_baidu_page(i*10)
    pages << doc.css("#container .result")
    i += 1
  end

  log "Get Pages Num: #{pages.size}"
  log "Get Items Num: #{total_num}"

  pages
end

# 得到所有页面的条目（一条搜索结果为一个条目(node)）
def get_nodes_of_pages(pages)
  nodes = []
  pages.each do |page|
    page.each do |item|
      origin_url = item.css(".f font .g")[0].content.to_s.strip
      origin_url = origin_url.split[0]
      origin_path = origin_url.gsub(/rubyer\.me/, '')
      origin_url = "http://" + origin_url
      nodes << {:origin_url => origin_url, :cache_url => item.css(".f font a")[0]["href"].to_s.strip, :origin_path => origin_path }
    end
  end
  nodes
end

# 处理每一个条目，并建议对应目录和文件，保存到硬盘里
def write_cache_to_disk(nodes)
  nodes.each do |node| 
    log "origin_url = #{node[:origin_url]}"
    log "cache_url  = #{node[:cache_url]}"
    log "origin_path = #{node[:origin_path]}"

    #原始地址为"/"说明是主页，名字改为index
    file_name = node[:origin_path].split("?")[0]
    #file_name = file_name == "/" ? "#{@path}/index" : @path + node[:origin_path]
    file_name = @path + file_name + "/index.html"
    #file_name = file_name + ".html"

    #make dir
    dir = File.dirname(file_name)
    FileUtils.mkdir_p(dir) unless File.exists?(dir)

    log "file_name=#{file_name}"

    #create a file and write the html
    #`wget -O "#{file_name}" #{node[:cache_url]}`
    File.open(file_name, "w") do |file|
      file.puts get_cache(get_source(node[:cache_url]))
    end
  end
end

pages = get_all_baidu_cache_pages
nodes = get_nodes_of_pages(pages)
write_cache_to_disk(nodes)
