# encoding: utf-8
require 'rubygems'
require 'sinatra'
require 'yaml'
require 'json_builder'
require 'redcarpet'
require 'securerandom'
require 'digest'
require 'cgi'

# PLEASE CHANGE THESE AS APPROPRIATE ON YOUR SYSTEM

# Path to the files (directories) in the filesystem which represent your articles
# or blog posts. This is matched to by the server to check whether it should give
# a 404 or process the request.
WWW_ROOT='/path/to/www/files'

# Path to the root of the place on the filesystem used to store comment files.
# This should exist before running the server.
COMMENTS_ROOT='/path/to/comment/store'

MARKDOWN = Redcarpet::Markdown.new(Redcarpet::Render::XHTML.new(:filter_html => true, 
                                                                :safe_links_only => true, 
                                                                :no_styles => true), 
                                   :autolink => true, 
                                   :no_intra_emphasis => true)

class APIError < StandardError
  def initialize(message)
    @message = message
  end

  def to_s
    @message
  end
end

class BlogComments
  def initialize(root)
    @root = root
    ['tmp', 'new', 'cur'].each {|dir| ensure_subdir(dir)}

    props_file = File.join(@root, 'properties.yaml')
    if File.exists? props_file
      @properties = YAML.load_file(props_file)
    else
      @properties = {'salt' => SecureRandom.random_bytes(32)}
      File.open(props_file, 'w') {|fh| fh.write(YAML.dump(@properties)) }
    end
  end

  def nonce_for(request_ip)
    sha256 = Digest::SHA256.new
    sha256 << request_ip
    sha256 << @root
    sha256 << @properties['salt']
    Digest.hexencode sha256.digest
  end

  def each
    cur_dir = File.join(@root, 'cur')
    Dir.entries(cur_dir).
      select {|d| d[0] != '.' }.
      sort.
      each {|file| yield YAML.load_file(File.join(cur_dir, file))}
  end

  def create(comment)
    file_name = Time.now.getutc.strftime('%Y%m%d%H%M%S') + sprintf('%04x', Process.pid) + SecureRandom.hex(8) + ".yaml"
    tmp_file = File.join(@root, 'tmp', file_name)
    cur_file = File.join(@root, 'cur', file_name)

    File.open(tmp_file, 'w') do |fh|
      fh.write(YAML.dump(comment))
    end

    File.link(tmp_file, cur_file)
    File.unlink(tmp_file)
  end

  def ensure_subdir(dir)
    subdir = File.join(@root, dir)
    FileUtils.mkdir_p(subdir) unless Dir.exists?(subdir)
  end
end

class ExistingBlogPostMatcher
  def initialize(root, extension)
    @root = root
    # note: if your pages are not of the form /YYYY/MM/DD/title/ then change this regex
    @pattern = /^\/([0-9]{4}\/[0-9]{2}\/[0-9]{2}\/.+)\/#{extension}$/
  end

  def match(str)
    match = @pattern.match(str)
    unless match.nil?
      match = nil if !Dir.exists?(File.join(@root, match[1]))
    end
    match
  end
end

def sanitise(str)
  CGI::escapeHTML(str)
end

def blog_comments(root, extension)
  ExistingBlogPostMatcher.new(root, extension)
end

def parse_request(request)
  if request.media_type == 'application/x-www-form-urlencoded'
    { 'author' => request.POST['author'],
      'nonce' => request.POST['nonce'],
      'content' => request.POST['content']
    }

  elsif request.media_type == 'application/json'
    JSON.parse(request.body)

  else
    raise APIError.new("Bad media-type: #{request.media_type.inspect} is not one of 'application/json' or 'application/x-www-form-urlencoded'.")
  end
end

get blog_comments(WWW_ROOT, 'comments.json') do |root|
  comments_ = BlogComments.new(File.join(COMMENTS_ROOT, root))
  client_nonce = comments_.nonce_for(request.ip)

  json = JSONBuilder::Compiler.generate do
    nonce client_nonce
    comments do
      array comments_ do |comment|
        author comment['author']
        timestamp comment['timestamp'].getutc.iso8601
        content comment['content']
      end
    end
  end

  [200, {'Content-Type' => 'application/json'}, json]
end

get blog_comments(WWW_ROOT, 'comments.xml') do |root|
  comments_ = BlogComments.new(File.join(COMMENTS_ROOT, root))
  # make atom feed here
end

post blog_comments(WWW_ROOT, 'comments.json') do |root|
  comments = BlogComments.new(File.join(COMMENTS_ROOT, root))

  begin
    req_data = parse_request(request)

    raise APIError.new("Input data is missing required 'author' field.")  if req_data['author'].nil?  || req_data['author'].empty?
    raise APIError.new("Input data is missing required 'content' field.") if req_data['content'].nil? || req_data['content'].empty?
    raise APIError.new("Mismatched nonce") if req_data['nonce'].nil? || (req_data['nonce'] != comments.nonce_for(request.ip))

    comment = {
      'request_ip' => request.ip.to_s.force_encoding('UTF-8'),
      'author' => sanitise(req_data['author']),
      'timestamp' => Time.now,
      'content' => MARKDOWN.render(req_data['content']),
      'user-agent' => request.user_agent.to_s.force_encoding('UTF-8')
    }

    comments.create(comment)

  rescue APIError => e
    # do some logging?
    json = JSONBuilder::Compiler.generate do
      status 400
      message e.to_s
    end

    [400, {'Content-Type' => 'application/json'}, json]

  rescue StandardError => e
    json = JSONBuilder::Compiler.generate do
      status 500
      message "Internal error."
    end

    [500, {'Content-Type' => 'application/json'}, json]

  else
    json = JSONBuilder::Compiler.generate do
      author comment['author']
      timestamp comment['timestamp'].getutc.iso8601
      content comment['content']      
    end

    [200, {'Content-Type' => 'application/json'}, json]
  end
end

