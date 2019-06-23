ExUnit.start()

for dir <- ["support"], file <- File.ls!("test/" <> dir) do
  Code.require_file(dir <> "/" <> file, __DIR__)
end
