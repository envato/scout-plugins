class CustomLoader
  def self.load!(env)
    Kernel.const_set('Loader', OpenStruct.new)
    Loader.adapter = "sqlite3"
    Loader.database = "db/test.sqlite3"
  end
end
