#
#  AppDelegate.rb
#  Houdini
#
#  Created by Daniel Westendorf on 2/20/12.
#  Copyright 2012 Daniel Westendorf. All rights reserved.
#

class AppDelegate
  attr_accessor :window

  def initialize
    @settings = NSUserDefaultsController.sharedUserDefaultsController
    @settings.setInitialValues({'rdesktop_path'=> '/usr/local/bin/rdesktop'})
  end

  def applicationDidFinishLaunching(a_notification)
    status_bar = NSStatusBar.systemStatusBar
    @status_item = status_bar.statusItemWithLength(NSVariableStatusItemLength)
    @status_item.setImage(NSImage.imageNamed('menu'))
    @status_item.setHighlightMode(true)
    
    NSNotificationCenter.defaultCenter.addObserver(self, selector:'managedObjectsChanged:', name:NSManagedObjectContextObjectsDidChangeNotification, object:nil)
    
    build_menu
  end
  
  def build_menu
    menu = NSMenu.alloc.initWithTitle("Houdini")
    menu.setDelegate(self)
    
    fetch_servers
    @servers.each do |server|
      break if server.host.nil? || server.host.empty?
      server_item = NSMenuItem.alloc
      server_item.representedObject = server
      server_item.setTitle(server.host)
      server_item.setAction("launch_rdp:")
      menu.addItem(server_item)
    end
    menu.addItem(NSMenuItem.separatorItem) if @servers.length > 0
    
    preference_item = NSMenuItem.alloc
    preference_item.setTitle("Preferences...")
    preference_item.setTarget(self)
    preference_item.setImage(NSImage.imageNamed('NSActionTemplate'))
    preference_item.setAction("show_preferences:")
    menu.addItem(preference_item)
    menu.addItem(NSMenuItem.separatorItem)
    
    quit_item = NSMenuItem.alloc
    quit_item.setTitle("Quit Houdini")
    quit_item.setTarget(self)
    quit_item.setAction("quit:")
    menu.addItem(quit_item)
    
    @status_item.setMenu(menu)
  end
  
  def launch_rdp(sender)
    object = sender.representedObject
    #command = @settings.values.valueForKey('rdesktop_path')
    command = []
    command << "-f" if object.fullscreen == 1
    command << "-g#{object.width}x#{object.height}" if object.fullscreen == 0
    command << "-T#{object.host}"
    command << "-u#{object.username}" if !object.username.nil? && !object.username.empty?
    command << "-d#{object.domain}" if !object.domain.nil? && !object.domain.empty?
    command << "#{object.switches}" if !object.switches.nil? && !object.switches.empty?
    command << "#{object.host}"
    task = NSTask.alloc.init
    pipe = NSPipe.alloc.init
    task.launchPath = @settings.values.valueForKey('rdesktop_path')
    task.arguments = command
    task.standardError = pipe
    NSNotificationCenter.defaultCenter.addObserver(self, selector:'task_finished_with_error:', name:NSFileHandleReadCompletionNotification, object:pipe.fileHandleForReading)
    pipe.fileHandleForReading.readInBackgroundAndNotify
    task.launch
  end
  
  def task_finished_with_error(notification)
    data = notification.userInfo[NSFileHandleNotificationDataItem]
    result = NSString.alloc.initWithData(data, encoding: NSUTF8StringEncoding)
    NSLog "#{result}"
    return unless result.scan(/Error/i).length > 0
    alert = NSAlert.alloc.init
    alert.addButtonWithTitle("Ok")
    alert.setMessageText("#{result}")
    alert.setInformativeText("There was a problem connecting to the host. Check your settings and try again.")
    alert.setAlertStyle(NSCriticalAlertStyle)
    alert.runModal
  end
  
  def fetch_servers
    request = NSFetchRequest.alloc.initWithEntityName('Server')
    servers = @managedObjectContext.executeFetchRequest(request, error:Pointer.new_with_type('@'))
    @servers = []
    servers.each {|server| @servers << server}
    begin
      @servers.sort_by! {|s| s.host}
    rescue
    end
  end
  
  def quit(sender)
    app = NSApplication.sharedApplication
    app.terminate(self)
  end
  
  def show_preferences(sender)
    @window.makeKeyAndOrderFront(nil)
    @window.setOrderedIndex(0)
    NSApp.activateIgnoringOtherApps(true)
    return true
  end
  
  
  def managedObjectsChanged(notification)
    build_menu
  end

  # Persistence accessors
  attr_reader :persistentStoreCoordinator
  attr_reader :managedObjectModel
  attr_reader :managedObjectContext

  #
  # Returns the directory the application uses to store the Core Data store file. This code uses a directory named "Houdini" in the user's Library directory.
  #
  def applicationFilesDirectory
    file_manager = NSFileManager.defaultManager
    library_url = file_manager.URLsForDirectory(NSLibraryDirectory, inDomains:NSUserDomainMask).lastObject
    library_url.URLByAppendingPathComponent("Houdini")
  end

  #
  # Creates if necessary and returns the managed object model for the application.
  #
  def managedObjectModel
      unless @managedObjectModel
        model_url = NSBundle.mainBundle.URLForResource("Houdini", withExtension:"momd")
        @managedObjectModel = NSManagedObjectModel.alloc.initWithContentsOfURL(model_url)
      end
      
      @managedObjectModel
  end

  #
  # Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
  #
  def persistentStoreCoordinator
      return @persistentStoreCoordinator if @persistentStoreCoordinator

      mom = self.managedObjectModel
      unless mom
          puts "#{self.class} No model to generate a store from"
          return nil
      end

      file_manager = NSFileManager.defaultManager
      directory = self.applicationFilesDirectory
      error = Pointer.new_with_type('@')

      properties = directory.resourceValuesForKeys([NSURLIsDirectoryKey], error:error)

      if properties.nil?
          ok = false
          if error[0].code == NSFileReadNoSuchFileError
              ok = file_manager.createDirectoryAtPath(directory.path, withIntermediateDirectories:true, attributes:nil, error:error)
          end
          if ok == false
              NSApplication.sharedApplication.presentError(error[0])
          end
      elsif properties[NSURLIsDirectoryKey] != true
              # Customize and localize this error.
              failure_description = "Expected a folder to store application data, found a file (#{directory.path})."

              error = NSError.errorWithDomain("YOUR_ERROR_DOMAIN", code:101, userInfo:{NSLocalizedDescriptionKey => failure_description})

              NSApplication.sharedApplication.presentError(error)
              return nil
      end

      url = directory.URLByAppendingPathComponent("Houdini.storedata")
      @persistentStoreCoordinator = NSPersistentStoreCoordinator.alloc.initWithManagedObjectModel(mom)

      unless @persistentStoreCoordinator.addPersistentStoreWithType(NSXMLStoreType, configuration:nil, URL:url, options:nil, error:error)
          NSApplication.sharedApplication.presentError(error[0])
          return nil
      end

      @persistentStoreCoordinator
  end

  #
  # Returns the managed object context for the application (which is already
  # bound to the persistent store coordinator for the application.) 
  #
  def managedObjectContext
      return @managedObjectContext if @managedObjectContext
      coordinator = self.persistentStoreCoordinator

      unless coordinator
          dict = {
              NSLocalizedDescriptionKey => "Failed to initialize the store",
              NSLocalizedFailureReasonErrorKey => "There was an error building up the data file."
          }
          error = NSError.errorWithDomain("YOUR_ERROR_DOMAIN", code:9999, userInfo:dict)
          NSApplication.sharedApplication.presentError(error)
          return nil
      end

      @managedObjectContext = NSManagedObjectContext.alloc.init
      @managedObjectContext.setPersistentStoreCoordinator(coordinator)

      @managedObjectContext
  end

  #
  # Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
  #
  def windowWillReturnUndoManager(window)
      self.managedObjectContext.undoManager
  end

  #
  # Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
  #
  def saveAction(sender)
      error = Pointer.new_with_type('@')

      unless self.managedObjectContext.commitEditing
        puts "#{self.class} unable to commit editing before saving"
      end

      unless self.managedObjectContext.save(error)
          NSApplication.sharedApplication.presentError(error[0])
      end
  end

  def applicationShouldTerminate(sender)
      # Save changes in the application's managed object context before the application terminates.

      return NSTerminateNow unless @managedObjectContext

      unless self.managedObjectContext.commitEditing
          puts "%@ unable to commit editing to terminate" % self.class
      end

      unless self.managedObjectContext.hasChanges
          return NSTerminateNow
      end

      error = Pointer.new_with_type('@')
      unless self.managedObjectContext.save(error)
          # Customize this code block to include application-specific recovery steps.
          return NSTerminateCancel if sender.presentError(error[0])

          alert = NSAlert.alloc.init
          alert.messageText = "Could not save changes while quitting. Quit anyway?"
          alert.informativeText = "Quitting now will lose any changes you have made since the last successful save"
          alert.addButtonWithTitle "Quit anyway"
          alert.addButtonWithTitle "Cancel"

          answer = alert.runModal
          return NSTerminateCancel if answer == NSAlertAlternateReturn
      end

      NSTerminateNow
  end
end

