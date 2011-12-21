require 'ga_rails'
require 'ga_rails_config'

%w{ models controllers helpers }.each do |dir|
   path = File.join(File.dirname(__FILE__), 'lib', dir)
   $LOAD_PATH << path
   if ActiveSupport::Dependencies.method_defined?(:autoload_paths)
     ActiveSupport::Dependencies.autoload_paths << path
   end
   if ActiveSupport::Dependencies.method_defined?(:autoload_once_paths)
     ActiveSupport::Dependencies.autoload_once_paths.delete(path)
   end
end

