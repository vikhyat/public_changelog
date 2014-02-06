require 'sinatra'
require 'octokit'
require 'digest/md5'

require 'yaml'

Octokit.configure do |c|
  c.access_token = ENV['GH_TOKEN']
end

def gravatar(email)
  hash = Digest::MD5.hexdigest(email.downcase)
  "http://www.gravatar.com/avatar/#{hash}"
end

class Changelog
  def initialize
    @repo = Octokit.repo(ENV["GH_REPO"])
    @commits = @repo.rels[:commits]
    update!
  end

  def last_update
    @last_update
  end

  def update!
    @last_update = Time.now
    @pages = []
    @pages.push @commits.get
    (ENV['MAX_PAGES'].to_i - 1).times do
      @pages.push @pages[-1].rels[:next].get
    end
  end

  def get_page(page=1)
    @pages[page-1]
  end

  def processed_page(page=1)
    process_response get_page(page).data
  end

  private
  def process_response(response)
    response.map do |x|
      commit = x.attrs[:commit].attrs
      {
        author: commit[:author].attrs,
        message: commit[:message],
        gravatar: gravatar(commit[:author].attrs[:email])
      }
    end
  end
end

$changelog = Changelog.new

Thread.new do
  sleep ENV['CACHE_DURATION'].to_i
  $changelog.update!
end

get '/' do
  @cover_image = ENV['COVER_IMAGE']
  @page = (params[:page] || 1).to_i
  @changelog = $changelog.processed_page(@page)
  @last_updated = $changelog.last_update
  erb :index
end

__END__

@@layout
<html>
  <head>
    <title><%= ENV['REPO_NAME'].downcase %> changelog</title>
    <link href="//netdna.bootstrapcdn.com/bootstrap/3.1.0/css/bootstrap.min.css" rel="stylesheet">
    <style type="text/css">
      .cover {
        position: relative;
        height: 330px;
        margin-top: -20px;
      }
      .cover .background-image, .cover .overlay {
        position: absolute;
        top: 0;
        left: 0;
        height: 100%;
        width: 100%;
      }
      .cover .background-image {
        background: url('<%= @cover_image %>') center center fixed no-repeat;
      }
      .cover .overlay {
        background: linear-gradient(to bottom, rgba(0,0,0,0.2), rgba(0,0,0,0.7));
      }
      .cover h1 {
        position: absolute;
        bottom: 0;
        color: rgba(255, 255, 255, 0.8);
        width: 100%;
        text-align: center;
      }
      .background-container {
        position: fixed;
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
        z-index: -1000;
        background: url('<%= @cover_image %>') center center fixed no-repeat;
        opacity: 0.5;
      }
      .contents {
        margin-top: 50px;
      }
      .contents .panel, .btn-group .btn {
        box-shadow: 0 2px 1px rgba(0,0,0,0.2);
        border: none;
        opacity: 0.9;
      }
      .commit {
        font-weight: bold;
      }
      .by-line img {
        height: 15px;
        width: 15px;
      }
      .by-line span.text {
        opacity: 0.7;
        font-size: 0.8em;
        margin-left: 5px;
      }
      .paginate {
        margin: 30px 0;
        float: right;
      }
      .footer {
        background-color: rgba(0,0,0,0.8);
        padding: 50px;
        text-align: center;
        color: rgba(255, 255, 255, 0.8);
      }
      .footer .last-update {
        opacity: 0.8;
        font-size: 0.9em;
      }
    </style>
  </head>
  <body>
    <div class="cover">
      <div class="background-image"></div>
      <div class="overlay"></div>
      <h1><%= ENV['REPO_NAME'].downcase %> changelog</h1>
    </div>
    <div class="background-container"></div>
    <div class="container">
      <div class="col-xs-12 col-md-6 col-md-offset-3 contents">
        <%= yield %>
      </div>
    </div>
    <div class="footer">
      <p>
        <div class="last-update">
          <em>Last Updated: <%= @last_updated %></em>
        </div>
      </p>
    </div>
  </body>
</html>

@@index
<% @changelog.each do |entry| %>
  <div class="panel panel-default">
    <div class="panel-body">
      <div class="commit">
        <%= entry[:message] %>
      </div>
      <div class="by-line">
        <img src="<%= entry[:gravatar] %>&s=140">
        <span class="text">
          <strong><%= entry[:author][:name] %></strong>
          authored on
          <%= entry[:author][:date].strftime("%d %B %Y") %>
        </span>
      </div>
    </div>
  </div>
<% end %>

<div class="paginate">
  <div class="btn-group">
    <% if @page > 1 %>
      <a class="btn btn-default" href="/?page=<%= @page - 1 %>">
        <span class="glyphicon glyphicon-chevron-left"></span>
        Previous
      </a>
    <% end %>
    <% if @page < ENV['MAX_PAGES'].to_i %>
      <a class="btn btn-default" href="/?page=<%= @page + 1 %>">
        Next
        <span class="glyphicon glyphicon-chevron-right"></span>
      </a>
    <% end %>
  </div>
</div>
