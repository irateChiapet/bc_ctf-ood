require 'sinatra'
require 'sinatra/base'
require 'pathname'

class MusicPlayer < Sinatra::Base
  get '/' do
    erb :index
  end

  get '/music/*' do
    # Serve music files from the public/music directory
    file_path = File.join('/var/www/ood/public/music', params['splat'].first)
    if File.exist?(file_path)
      content_type File.extname(file_path)
      send_file file_path
    else
      halt 404, "File not found"
    end
  end

  get '/api/playlist' do
    content_type :json
    music_dir = '/var/www/ood/public/music'
    return [].to_json unless Dir.exist?(music_dir)

    files = Dir.glob(File.join(music_dir, "*.{mp3,wav,ogg,m4a}"))
                .map { |f| File.basename(f) }
                .sort

    files.to_json
  end
end