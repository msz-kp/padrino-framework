require File.expand_path(File.dirname(__FILE__) + '/helper')

describe "Filters" do
  it 'should filters by accept header' do
    mock_app do
      get '/foo', :provides => [:xml, :js] do
        request.env['HTTP_ACCEPT']
      end
    end

    get '/foo', {}, { 'HTTP_ACCEPT' => 'application/xml' }
    assert ok?
    assert_equal 'application/xml', body
    assert_equal 'application/xml;charset=utf-8', response.headers['content-type']

    get '/foo.xml'
    assert ok?
    assert_equal 'application/xml;charset=utf-8', response.headers['content-type']

    get '/foo', {}, { 'HTTP_ACCEPT' => 'application/javascript' }
    assert ok?
    assert_equal 'application/javascript', body
    assert_equal 'application/javascript;charset=utf-8', response.headers['content-type']

    get '/foo.js'
    assert ok?
    assert_equal 'application/javascript;charset=utf-8', response.headers['content-type']

    get '/foo', {}, { "HTTP_ACCEPT" => 'text/html' }
    assert_equal 406, status
  end

  it 'should allow passing & halting in before filters' do
    mock_app do
      controller do
        before { env['QUERY_STRING'] == 'secret' or pass }
        get :index do
          "secret index"
        end
      end

      controller do
        before { env['QUERY_STRING'] == 'halt' and halt 401, 'go away!' }
        get :index do
          "index"
        end
      end
    end

    get "/?secret"
    assert_equal "secret index", body

    get "/?halt"
    assert_equal "go away!", body
    assert_equal 401, status

    get "/"
    assert_equal "index", body
  end

  it 'should scope filters in the given controller' do
    mock_app do
      before { @global = 'global' }
      after { @global = nil }

      controller :foo do
        before { @foo = :foo }
        after { @foo = nil }
        get("/") { [@foo, @bar, @global].compact.join(" ") }
      end

      get("/") { [@foo, @bar, @global].compact.join(" ") }

      controller :bar do
        before { @bar = :bar }
        after { @bar = nil }
        get("/") { [@foo, @bar, @global].compact.join(" ") }
      end
    end

    get "/bar"
    assert_equal "bar global", body

    get "/foo"
    assert_equal "foo global", body

    get "/"
    assert_equal "global", body
  end

  it 'should be able to access params in a before filter' do
    username_from_before_filter = nil

    mock_app do
      before do
        username_from_before_filter = params[:username]
      end

      get :users, :with => :username do
      end
    end
    get '/users/josh'
    assert_equal 'josh', username_from_before_filter
  end

  it 'should be able to access params normally when a before filter is specified' do
    mock_app do
      before { }
      get :index do
        params.inspect
      end
    end
    get '/?test=what'
    assert_equal '{"test"=>"what"}', body
  end

  it 'should be able to filter based on a path' do
    mock_app do
      before('/') { @test = "#{@test}before"}
      get :index do
        @test
      end
      get :main do
        @test
      end
    end
    get '/'
    assert_equal 'before', body
    get '/main'
    assert_equal '', body
  end

  it 'should be able to filter based on a symbol' do
    mock_app do
      before(:index) { @test = 'before'}
      get :index do
        @test
      end
      get :main do
        @test
      end
    end
    get '/'
    assert_equal 'before', body
    get '/main'
    assert_equal '', body
  end

  it 'should be able to filter based on a symbol for a controller' do
    mock_app do
      controller :foo do
        before(:test) { @test = 'foo'}
        get :test do
          @test.to_s + " response"
        end
      end
      controller :bar do
        before(:test) { @test = 'bar'}
        get :test do
          @test.to_s + " response"
        end
      end
    end
    get '/foo/test'
    assert_equal 'foo response', body
    get '/bar/test'
    assert_equal 'bar response', body
  end

  it 'should be able to filter based on a symbol or path' do
    mock_app do
      before(:index, '/main') { @test = 'before'}
      get :index do
        @test
      end
      get :main do
        @test
      end
    end
    get '/'
    assert_equal 'before', body
    get '/main'
    assert_equal 'before', body
  end

  it 'should be able to filter based on a symbol or regexp' do
    mock_app do
      before(:index, /main/) { @test = 'before'}
      get :index do
        @test
      end
      get :main do
        @test
      end
      get :profile do
        @test
      end
    end
    get '/'
    assert_equal 'before', body
    get '/main'
    assert_equal 'before', body
    get '/profile'
    assert_equal '', body
  end

  it 'should be able to filter excluding based on a symbol' do
    mock_app do
      before(:except => :index) { @test = 'before'}
      get :index do
        @test
      end
      get :main do
        @test
      end
    end
    get '/'
    assert_equal '', body
    get '/main'
    assert_equal 'before', body
  end

  it 'should be able to filter excluding based on a symbol when specify the multiple routes and use nested controller' do
    mock_app do
      controller :test, :nested do
        before(:except => [:test1, :test2]) { @long = 'long'}
        before(:except => [:test1]) { @short = 'short'}
        get :test1 do
          "#{@long} #{@short} normal"
        end
        get :test2 do
          "#{@long} #{@short} normal"
        end
        get :test3 do
          "#{@long} #{@short} normal"
        end
      end
    end
    get '/test/nested/test1'
    assert_equal '  normal', body
    get '/test/nested/test2'
    assert_equal ' short normal', body
    get '/test/nested/test3'
    assert_equal 'long short normal', body
  end

  it 'should be able to filter based on a request param' do
    mock_app do
      before(:agent => /IE/) { @test = 'before'}
      get :index do
        @test
      end
    end
    get '/'
    assert_equal '', body
    get "/", {}, {'HTTP_USER_AGENT' => 'This is IE'}
    assert_equal 'before', body
  end

  it 'should be able to filter based on a symbol or path in multiple controller' do
    mock_app do
      controllers :foo do
        before(:index, '/foo/main') { @test = 'before' }
        get :index do
          @test
        end
        get :main do
          @test
        end
      end
      controllers :bar do
        before(:index, '/bar/main') { @test = 'also before' }
        get :index do
          @test
        end
        get :main do
          @test
        end
      end
    end
    get '/foo'
    assert_equal 'before', body
    get '/bar'
    assert_equal 'also before', body
    get '/foo/main'
    assert_equal 'before', body
    get '/bar/main'
    assert_equal 'also before', body
  end

  it 'should call before filters even if there was no match' do
    test = nil
    mock_app do
      before(:index, '/foo') { test = 'before' }
      get :index do
        ''
      end
    end
    get '/foo'
    assert_equal 'before', test
  end

  it 'should ensure the call of before_filter at the first time' do
    once = ''
    mock_app do
      before do
        once += 'before'
      end
      get :index do
        raise Exception, 'Oops'
      end
      post :index do
        raise Exception, 'Oops'
      end
    end

    post '/'
    assert_equal 'before', once
  end

  it 'should call before filters only once' do
    once = ''
    mock_app do
      error 500 do
        'error 500'
      end
      before do
        once += 'before'
      end
      get :index do
        raise Exception, 'Oops'
      end
    end

    get '/'
    assert_equal 'before', once
  end

  it 'should catch exceptions in before filters' do
    doodle = ''
    mock_app do
      after do
        doodle = 'Been after'
      end
      before do
        raise StandardError, "before"
      end
      get :index do
        doodle = 'Been now'
      end
      error 500 do
        "We broke #{env['sinatra.error'].message}"
      end
    end

    get '/'
    assert_equal 'We broke before', body
    assert_equal '', doodle
  end

  it 'should catch exceptions in after filters if no exceptions caught before' do
    doodle = ''
    mock_app do
      after do
        doodle += ' and after'
        raise StandardError, "after"
      end
      get :foo do
        doodle = 'Been now'
        raise StandardError, "now"
      end
      get :index do
        doodle = 'Been now'
      end
      error 500 do
        "We broke #{env['sinatra.error'].message}"
      end
    end

    get '/foo'
    assert_equal 'We broke now', body
    assert_equal 'Been now', doodle

    doodle = ''
    get '/'
    assert_equal 'We broke after', body
    assert_equal 'Been now and after', doodle
  end

  it 'should trigger filters if superclass responds to :filters' do
    class FilterApp < Padrino::Application
      before { @foo = "foo" }
    end
    mock_app FilterApp do
      get("/") { @foo }
    end
    get "/"
    assert_equal "foo", body
  end
end
