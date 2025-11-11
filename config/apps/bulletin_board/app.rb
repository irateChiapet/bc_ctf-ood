require 'sinatra'
require 'sinatra/base'
require 'json'
require 'pathname'
require 'fileutils'

class BulletinBoard < Sinatra::Base
  # Set data directory for persistent storage
  DATA_DIR = '/var/lib/ood/bulletin_board'
  POSTS_FILE = File.join(DATA_DIR, 'posts.json')

  # Ensure data directory exists with secure permissions
  before do
    unless Dir.exist?(DATA_DIR)
      FileUtils.mkdir_p(DATA_DIR, mode: 0700)
    end
  end

  # GET - Render the bulletin board widget
  get '/' do
    erb :index
  end

  # API: Get all posts
  get '/api/posts' do
    content_type :json

    # Load posts from file
    if File.exist?(POSTS_FILE)
      posts = JSON.parse(File.read(POSTS_FILE))
      posts.to_json
    else
      [].to_json
    end
  rescue => e
    status 500
    { error: "Failed to load posts: #{e.message}" }.to_json
  end

  # API: Create a new post
  post '/api/posts' do
    content_type :json

    # Parse request body
    payload = JSON.parse(request.body.read)

    # Validate required fields
    if payload['content'].nil? || payload['content'].to_s.strip.empty?
      status 400
      return { error: 'Post content is required' }.to_json
    end

    # Get current user from OOD environment
    user = ENV['REMOTE_USER'] || 'Anonymous'

    # Create post object
    post = {
      id: generate_post_id,
      author: user,
      title: payload['title'].to_s.strip[0..199],  # Limit to 200 chars
      content: payload['content'].to_s.strip,
      timestamp: Time.now.to_i,
      created_at: Time.now.iso8601
    }

    # Load existing posts
    posts = load_posts

    # Add new post
    posts.unshift(post)

    # Save posts to file
    save_posts(posts)

    status 201
    post.to_json
  rescue JSON::ParserError
    status 400
    { error: 'Invalid JSON payload' }.to_json
  rescue => e
    status 500
    { error: "Failed to create post: #{e.message}" }.to_json
  end

  # API: Delete a post (only by author)
  delete '/api/posts/:id' do
    content_type :json

    post_id = params['id']
    user = ENV['REMOTE_USER'] || 'Anonymous'

    # Load posts
    posts = load_posts

    # Find the post to delete
    post = posts.find { |p| p['id'] == post_id }

    unless post
      status 404
      return { error: 'Post not found' }.to_json
    end

    # Check authorization (only author can delete)
    unless post['author'] == user
      status 403
      return { error: 'You can only delete your own posts' }.to_json
    end

    # Remove post
    posts.delete_if { |p| p['id'] == post_id }

    # Save updated posts
    save_posts(posts)

    status 200
    { message: 'Post deleted successfully' }.to_json
  rescue => e
    status 500
    { error: "Failed to delete post: #{e.message}" }.to_json
  end

  # API: Get current user info
  get '/api/user' do
    content_type :json
    user = ENV['REMOTE_USER'] || 'Anonymous'
    { user: user }.to_json
  end

  private

  # Load posts from JSON file
  def load_posts
    if File.exist?(POSTS_FILE)
      JSON.parse(File.read(POSTS_FILE))
    else
      []
    end
  rescue => e
    puts "Error loading posts: #{e.message}"
    []
  end

  # Save posts to JSON file
  def save_posts(posts)
    # Write atomically with temp file
    temp_file = "#{POSTS_FILE}.tmp"
    File.write(temp_file, JSON.pretty_generate(posts))
    File.chmod(0600, temp_file)  # Secure permissions
    File.rename(temp_file, POSTS_FILE)
    File.chmod(0600, POSTS_FILE)  # Ensure secure permissions
  rescue => e
    puts "Error saving posts: #{e.message}"
    raise
  end

  # Generate unique post ID (timestamp-based)
  def generate_post_id
    "#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end
end
