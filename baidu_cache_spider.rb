#coding: utf-8
require 'nokogiri'
require 'open-uri'

# 我要抓取的地址，不能有http
@my_url = "rubyer.me"
# 所有快照源码存放的路径
@path = "/rubyer_cache"

@log_file = File.new("info.txt", "w+")

BAIDU_CACHE_URL = "http://www.baidu.com/s?wd=site:%s"
BAIDU_CACHE_PAGE_URL = "http://www.baidu.com/s?wd=site:%s?&pn=%d"

# 根据url得到网页源码
def get_source(url)
	#sleep for a while or baidu will block you
	@log_file.puts "sleep for:" + sleep(rand 5).to_s
	str = open(url).read
	p str.encoding
	#str = str.encode("utf-8", "GBK")
	#str = convert_encoding("utf-8", "ASCII-8BIT", str)
	str = convert_encoding("utf-8", "GB2312", str)
	p str.encoding
	Nokogiri::HTML.parse(str)
end

# 抓取第page_num页的源码
def get_source_of_baidu_page(page_num)
	url = BAIDU_CACHE_PAGE_URL % [@my_url, page_num]
	get_source(url)
end

# 编码转换，这里我被搞晕了
def convert_encoding(source_encoding, destination_encoding, str)
	ec = Encoding::Converter.new(source_encoding, destination_encoding)
	begin
	  ec.convert(str)
	rescue Encoding::UndefinedConversionError
	  @log_file.puts $!.error_char.dump
	  p $!.error_char.encoding
	rescue Encoding::InvalidByteSequenceError
	  p $!
	  @log_file.puts $!.error_bytes.dump  if $!.error_bytes
	  @log_file.puts $!.readagain_bytes.dump if $!.readagain_bytes
	end
	str
end

# 从百度快照源码抽取出有用的信息，其实这就是原始网站源码
def get_cache(source_html)
	if source_html.xpath("/html/body/div[3]")[0]
		source_html.xpath("/html/body/div[3]")[0].inner_html
	else
		#有一些页面快照结构有问题，打出来，手工分析
		@log_file.puts "===============get cache error occurs next==================================="
		@log_file.puts source_html
		@log_file.puts "===============get cache error occurs above=================================="
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
	
	@log_file.puts "Get Pages Num: #{pages.size}"
	@log_file.puts "Get Items Num: #{total_num}"

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
		@log_file.puts "origin_url = #{node[:origin_url]}"
		@log_file.puts "cache_url  = #{node[:cache_url]}"
		@log_file.puts "origin_path = #{node[:origin_path]}"
		
		#原始地址为"/"说明是主页，名字改为index
		file_name = node[:origin_path] == "/" ? "#{@path}/index" : @path + node[:origin_path]
		file_name = file_name.split("?")[0]
		file_name = file_name + ".html"
		
		#make dir
		dir = File.dirname(file_name)
		FileUtils.mkdir_p(dir) unless File.exists?(dir)
		
		@log_file.puts "file_name=#{file_name}"
		
		#create a file and write the html
		File.open(file_name, "w") do |file|
			file.puts get_cache(get_source(node[:cache_url]))
		end
	end
end

pages = get_all_baidu_cache_pages
nodes = get_nodes_of_pages(pages)
write_cache_to_disk(nodes)

@log_file.close