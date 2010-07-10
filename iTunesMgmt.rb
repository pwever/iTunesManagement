#!/usr/bin/ruby

require 'rubygems'
require 'appscript'
require 'ftools'
include Appscript

REMOTE_URL = "eppc://Bangkok.local/iTunes"

def transferRatings(source="Newly Added")
  
  # Transfer the ratings of all songs found in source
  # to the remote computer
  
  local = app("iTunes")
  local_playlist = local.playlists.get.find { |pl| pl.name.get.downcase==source.downcase }
  
  local_index = {}
  local_tracks = local_playlist.tracks.get.select { |t| t.rating.get>0 }
  
  local_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    local_index[key] = t
  end
  
  # remote
  
  remote = app.by_url(REMOTE_URL)
  remote_tracks = remote.playlists.get[0].tracks.get.select { |t| t.rating.get==0 }
  
  remote_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    if local_index[key]
      t.rating.set(local_index[key].rating.get)
      p "Rated %s." % t.name.get
    end
  end
  
end



def transferDuplicateRatings()
  #remote = app.by_url(REMOTE_URL)
  local = app("iTunes")
  #source = "tester"
  #playlist = remote.playlists.get.find { |pl| pl.name.get.downcase==source.downcase }
  playlist = local.playlists.get[0]
  tracks = playlist.tracks.get
  
  p "Fetched all tracks (%i)" % tracks.length
  
  tracks_rated_dict = {}
  tracks_unrated_dict = {}
  tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    if (t.rating.get!=0)
      tracks_rated_dict[key] = t
    else
      tracks_unrated_dict[key] = t
    end
  end
  
  p "Identified unrated songs"
  
  n = 0
  tracks_unrated_dict.each do |k,t|
    if tracks_rated_dict[k]
      t.rating.set(tracks_rated_dict[k].rating.get)
      p "Rated %s." % t.name.get
    else
      n += 1
    end
  end
  
  p "No rated equivalent found for %i tracks" % n
end


def findMissingFiles()
  #itunes = app.by_url(REMOTE_URL)
  itunes = app("iTunes")
  tracks = itunes.playlists.get[0].tracks.get
  
  p "Fetched all tracks (%i)" % tracks.length
  
  missing = tracks.select do |t|
    begin
      t.location.get == :missing_value
    rescue
      p "No location for %s." % t.name.get
      false
    end
  end
  
  missing.each do |t|
    p "Deleted %s." % t.name.get
    t.delete
  end
  
end



def copyUnmatched(source="Newly Added", destination=nil)
  
  # Copies all songs in source playlist
  # that are not found on the remote machine
  # to the destination (mount remote machine share first)
  
  if destination.nil?
    printHelp
    return
  end
  
  local = app("iTunes")
  local_playlist = local.playlists.get.find { |pl| pl.name.get.downcase==source.downcase }
  
  if local_playlist.nil?
    printHelp
    return
  end
  
  local_index = {}
  local_tracks = local_playlist.tracks.get
  
  local_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    local_index[key] = t
  end
  
  # remote
  
  remote = app.by_url(REMOTE_URL)
  remote_tracks = remote.playlists.get[0].tracks.get
  
  remote_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    if local_index.key?(key)
      local_index.delete(key)
    end
  end
  
  local_index.each do |k,t|
    begin
      File.copy(t.location.get.path, destination)
      p "Copied %s." % t.location.get.path
    rescue
      p "Unable to copy '%s'." % t.name
    end
  end
  
end

def buildMatchedPlaylist(destination)
  
  # Creates a playlist (destination) on the local computer,
  # that contains all the songs already on the remote machine.
  
  if destination.nil?
    printHelp
    return
  end
  
  local = app("iTunes")
  local_playlist = local.playlists.get[0]
  
  if local_playlist.nil?
    printHelp
    return
  end
  
  local_index = {}
  local_tracks = local_playlist.tracks.get
  
  local_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    local_index[key] = t
  end
  
  # Create the local playlist
  begin
    target_playlist = local.playlists[destination].get
  rescue
    local.make(:new=>:user_playlist, :with_properties=>{:name=>destination})
    target_playlist = local.playlists[destination].get
  end
  
  # remote
  
  remote = app.by_url(REMOTE_URL)
  remote_tracks = remote.playlists.get[0].tracks.get
  
  remote_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    if local_index.key?(key)
      # Add the song to a local playlist (destination)
      local_index[key].duplicate(:to => target_playlist)
      p "Found matching song: %s." % local_index[key].name.get
    end
  end
  
end

def collectUmatched(destination)
  
  # Creates a playlist (destination) on the local computer,
  # that contains all the songs *NOT* found on remote machine.
  
  if destination.nil?
    printHelp
    return
  end
  
  local = app("iTunes")
  local_playlist = local.playlists.get[0]
  
  if local_playlist.nil?
    printHelp
    return
  end
  
  local_index = {}
  local_tracks = local_playlist.tracks.get
  
  local_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    local_index[key] = t
  end
  
  # Create the local playlist
  begin
    target_playlist = local.playlists[destination].get
  rescue
    local.make(:new=>:user_playlist, :with_properties=>{:name=>destination})
    target_playlist = local.playlists[destination].get
  end
  
  # remote
  
  remote = app.by_url(REMOTE_URL)
  remote_tracks = remote.playlists.get[0].tracks.get
  
  remote_tracks.each do |t|
    key = "%s:%s:%s" % [t.artist.get, t.album.get, t.name.get]
    if local_index.key?(key)
      p "Found matching song: %s." % local_index[key].name.get
      local_index.delete(key)
    end
  end
  
  local_index.each do |k,t|
    # Add the song to a local playlist (destination)
    t.duplicate(:to => target_playlist)
  end
  
end

def findOneHitWonders()
  # Find artists that have only ONE song in the library
  
  itunes = app("iTunes");
  #itunes = app.by_url(REMOTE_URL)
  tracks = itunes.playlists.get[0].tracks.get
  
  # create a dict with artists as key, and songs as content
  artists = {}
  tracks.each do |t|
    if (artists[t.artist.get])
      artists[t.artist.get] << t
    else
      artists[t.artist.get] = [t]
    end
  end
  
  # create or clear OneHitWonders playlist
  playlist_name = "OneHitWonders"
  if (itunes.playlists.get.find {|pl| pl.name.get.downcase==playlist_name.downcase})
    itunes.playlists[playlist_name].delete
  end
  itunes.make(:new=>:user_playlist, :with_properties=>{:name=>playlist_name})
  destination = itunes.playlists[playlist_name].get
  
  # loop through dict, and identify all artists with only one song
  # add to playlist
  artists.each do |k,tracks|
    if (tracks.length==1)
      tracks[0].duplicate(:to => destination)
    end
  end
  
  p "Copied all one-hit songs to %s. (%i)" % [playlist_name, destination.tracks.get.length]
  
end

def findLowRatedOneHitWonders()
  itunes = app("iTunes");
  #itunes = app.by_url(REMOTE_URL)
  tracks = itunes.playlists.get[0].tracks.get
  
  # create a dict with artists as key, and songs as content
  artists = {}
  tracks.each do |t|
    if (artists[t.artist.get])
      artists[t.artist.get] << t
    else
      artists[t.artist.get] = [t]
    end
  end
  
  # create or clear OneHitWonders playlist
  playlist_name = "LowRatedOneHitWonders"
  if (itunes.playlists.get.find {|pl| pl.name.get.downcase==playlist_name.downcase})
    itunes.playlists[playlist_name].delete
  end
  itunes.make(:new=>:user_playlist, :with_properties=>{:name=>playlist_name})
  destination = itunes.playlists[playlist_name].get
  
  # loop through dict, and identify all artists with only one song
  # add to playlist
  artists.each do |k,tracks|
    if (tracks.length==1)
      tracks[0].duplicate(:to => destination) if (tracks[0].rating.get<50 && tracks[0].rating.get!=0)
    end
  end
  
  p "Copied all one-hit songs to %s. (%i)" % [playlist_name, destination.tracks.get.length]
end


def deleteLowRatedOneHitWonders()
  itunes = app("iTunes");
  #itunes = app.by_url(REMOTE_URL)
  tracks = itunes.playlists.get[0].tracks.get
  
  # create a dict with artists as key, and songs as content
  artists = {}
  tracks.each do |t|
    if (artists[t.artist.get])
      artists[t.artist.get] << t
    else
      artists[t.artist.get] = [t]
    end
  end
  
  # create or clear OneHitWonders playlist
  playlist_name = "LowRatedOneHitWonders"
  if (itunes.playlists.get.find {|pl| pl.name.get.downcase==playlist_name.downcase})
    itunes.playlists[playlist_name].delete
  end
  itunes.make(:new=>:user_playlist, :with_properties=>{:name=>playlist_name})
  destination = itunes.playlists[playlist_name].get
  
  # loop through dict, and identify all artists with only one song
  # add to playlist
  artists.each do |k,tracks|
    if (tracks.length==1)
      tracks[0].delete if (tracks[0].rating.get<50 && tracks[0].rating.get!=0)
    end
  end
  
  p "Deleted all one-hit songs with low ratings. (%i)" % destination.tracks.get.length
end


def printHelp
  puts "
  # Rate tracks found in the remote library
  ruby #{__FILE__} rate [playlist_name=Newly\ Added]
  
  # Copy local playlist to remote library
  ruby #{__FILE__} copy playlist_name destination_path
  
  # Create a playlist with tracks found in remote library
  ruby #{__FILE__} matched target_playlist_name
  
  # Create a playlist with tracks NOT found in remote library
  ruby #{__FILE__} unmatched target_playlist_name
  
  # Rate unrated songs, that have rated duplicates
  ruby #{__FILE__} duplicates
  
  # Delete tracks with missing files
  ruby #{__FILE__} missing
  
  # Create a playlist with artists that only have one song in local library
  ruby #{__FILE__} onehitswonders
  
  # Create a playlist with low rated one hit wonders
  ruby #{__FILE__} lowratedonehitwonders
  
  # Delete low rated one hit wonders from your library
  ruby #{__FILE__} deletelowratedonehitwonders
  "
end



if $0 == __FILE__
  if $*.length>0
    if $*[0]=="-h"
      printHelp
    elsif $*[0].downcase=="copy" && $*.length>=3
      copyUnmatched($*[1], $*[2])
    elsif $*[0].downcase=="rate"
      transferRatings
    elsif $*[0].downcase=="matched" && $*.length>=2
      buildMatchedPlaylist($*[1])
    elsif $*[0].downcase=="unmatched" && $*.length>=2
      collectUmatched($*[1])
    elsif $*[0].downcase=="duplicates"
      transferDuplicateRatings()
    elsif $*[0].downcase=="missing"
      findMissingFiles()
    elsif $*[0].downcase=="onehitwonders"
      findOneHitWonders()
    elsif $*[0].downcase=="lowratedonehitwonders"
      findLowRatedOneHitWonders()
    elsif $*[0].downcase=="deletelowratedonehitwonders"
        deleteLowRatedOneHitWonders()
    else
      printHelp
    end
  else
    printHelp
  end
end



