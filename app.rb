require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require

env_index = ARGV.index("-e")
env_arg = ARGV[env_index + 1] if env_index
env = env_arg || ENV["SINATRA_ENV"] || "development"

module CommentService
  class << self; attr_accessor :config; end
end

CommentService.config = YAML.load_file("config/application.yml")

Mongoid.load!("config/mongoid.yml")
Mongoid.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file}

# DELETE /api/v1/commentables/:commentable_type/:commentable_id
# delete the commentable object and all of its associated comment threads and comments
delete '/api/v1/:commentable_type/:commentable_id/comments' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_initialize_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.destroy
  commentable.to_hash.to_json
end

# GET /api/v1/commentables/:commentable_type/:commentable_id/threads
# get all comment threads associated with a commentable object
# additional parameters accepted: recursive

get '/api/v1/:commentable_type/:commentable_id/threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  commentable.comment_threads.map{|t| t.to_hash(recursive: params["recursive"])}.to_json
end

# POST /api/v1/commentables/:commentable_type/:commentable_id/threads
# create a new comment thread for the commentable object

post '/api/v1/:commentable_type/:commentable_id/threads' do |commentable_type, commentable_id|
  commentable = Commentable.find_or_create_by(commentable_type: commentable_type, commentable_id: commentable_id)
  thread = commentable.comment_threads.new(params.slice(*%w[title body course_id]))
  thread.author = User.find_or_create_by(external_id: params["user_id"]) if params["user_id"]
  thread.save!
  thread.to_hash.to_json
end

# GET /api/v1/threads/:thread_id
# get information of a single comment thread
# additional parameters accepted: recursive

get '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.to_hash(recursive: params["recursive"]).to_json
end

# PUT /api/v1/threads/:thread_id
# update information of comment thread

put '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.update_attributes!(params.slice(*%w[title body]))
  thread.to_hash.to_json
end

# POST /api/v1/threads/:thread_id/comments
# create a comment to the comment thread
post '/api/v1/threads/:thread_id/comments' do |thread_id|
  thread = CommentThread.find(thread_id)
  comment = thread.comments.new(params.slice(*%w[body course_id]))
  comment.author = User.find_or_create_by(external_id: params["user_id"]) if params["user_id"]
  comment.save!
  comment.to_hash.to_json
end

# DELETE /api/v1/threads/:thread_id
# delete the comment thread and its comments

delete '/api/v1/threads/:thread_id' do |thread_id|
  thread = CommentThread.find(thread_id)
  thread.destroy
  thread.to_hash.to_json
end

# GET /api/v1/comments/:comment_id
# retrieve information of a single comment
# additional parameters accepted: recursive

get '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.to_hash(recursive: params["recursive"]).to_json
end

# PUT /api/v1/comments/:comment_id
# update information of the comment

put '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.update_attributes!(params.slice(*%w[body endorsed]))
  comment.to_hash.to_json
end

# POST /api/v1/comments/:comment_id
# create a sub comment to the comment

post '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  sub_comment = comment.children.new(params.slice(*%w[body course_id]))
  sub_comment.author = User.find_or_create_by(external_id: params["user_id"])
  sub_comment.save!
  sub_comment.to_hash.to_json
end

# DELETE /api/v1/comments/:comment_id
# delete the comment and its sub comments

delete '/api/v1/comments/:comment_id' do |comment_id|
  comment = Comment.find(comment_id)
  comment.destroy
  comment.to_hash.to_json
end

# PUT /api/v1/votes/comments/:comment_id/users/:user_id
# create or update the vote on the comment

put '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  comment = Comment.find(comment_id)
  user = User.find_or_create_by(external_id: user_id)
  user.vote(comment, params["value"].intern)
  Comment.find(comment_id).to_hash.to_json
end

# DELETE /api/v1/votes/comments/:comment_id/users/:user_id
# unvote on the comment

delete '/api/v1/votes/comments/:comment_id/users/:user_id' do |comment_id, user_id|
  comment = Comment.find(comment_id)
  user = User.find_or_create_by(external_id: user_id)
  user.unvote(comment)
  Comment.find(comment_id).to_hash.to_json
end

# PUT /api/v1/votes/threads/:thread_id/users/:user_id
# create or update the vote on the comment thread

put '/api/v1/votes/threads/:thread_id/users/:user_id' do |thread_id, user_id|
  thread = CommentThread.find(thread_id)
  user = User.find_or_create_by(external_id: user_id)
  user.vote(thread, params["value"].intern)
  CommentThread.find(thread_id).to_hash.to_json
end

# DELETE /api/v1/votes/threads/:thread_id/users/:user_id
# unvote on the comment thread

delete '/api/v1/votes/threads/:thread_id/users/:user_id' do |thread_id, user_id|
  thread = CommentThread.find(thread_id)
  user = User.find_or_create_by(external_id: user_id)
  user.unvote(thread)
  CommentThread.find(thread_id).to_hash.to_json
end

# GET /api/v1/users/:user_id/feeds
# get all subscribed feeds for the user

get '/api/v1/users/:user_id/feeds' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  user.subscribed_feeds.map(&:to_hash).to_json
end

# POST /api/v1/users/:user_id/follow
# follow user

post '/api/v1/users/:user_id/follow' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  followed_user = User.find_or_create_by(external_id: params["follow_user_id"])
  user.follow(followed_user)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unfollow
# unfollow user

post '/api/v1/users/:user_id/unfollow' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  followed_user = User.find_or_create_by(external_id: params["follow_user_id"])
  user.unfollow(followed_user)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/watch/commentable
# watch a commentable

post '/api/v1/users/:user_id/watch/commentable' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  commentable = Commentable.find_or_create_by(commentable_type: params[:commentable_type],
                                              commentable_id: params[:commentable_id])
  user.watch_commentable(commentable)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unwatch/commentable
# unwatch a commentable

post '/api/v1/users/:user_id/unwatch/commentable' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  commentable = Commentable.find_or_create_by(commentable_type: params["commentable_type"],
                                              commentable_id: params["commentable_id"])
  user.unwatch_commentable(commentable)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/watch/thread
# watch a comment thread

post '/api/v1/users/:user_id/watch/thread' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  thread = CommentThread.find(params["thread_id"])
  user.watch_comment_thread(thread)
  user.to_hash.to_json
end

# POST /api/v1/users/:user_id/unwatch/thread
# unwatch a comment thread

post '/api/v1/users/:user_id/unwatch/thread' do |user_id|
  user = User.find_or_create_by(external_id: user_id)
  thread = CommentThread.find(params["thread_id"])
  user.unwatch_comment_thread(thread)
  user.to_hash.to_json
end

if env.to_s == "development"
  get '/api/v1/clean' do
    Comment.delete_all
    CommentThread.delete_all
    Commentable.delete_all
    User.delete_all
    Feed.delete_all
    {}.to_json
  end
end
