# edit-variable-page
# --------------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.jsoneditor))

$(document).on("pagebeforecreate", '#edit-device-page', (event) ->
  if pimatic.pages.editDevice? then return
  
  class EditDeviceViewModel

    action: ko.observable('add')
    deviceName: ko.observable('')
    deviceId: ko.observable('')
    deviceClass: ko.observable('')
    deviceClasses: ko.observableArray()
    deviceConfig: ko.observable({})
    configSchema: ko.observable(null)
    editor: null

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Device') else __('Edit Device'))
      )

      editorEle = $('#device-json-editor')
      pimatic.autoFillId(@deviceName, @deviceId, @action)
      
      editorSetConfig = (config) =>
        unless @editor? then return
        deviceConfig = @deviceConfig()
        confCopy = {}
        count = 0
        for k, v of deviceConfig
          unless k in ['name', 'id', 'class']
            confCopy[k] = v
            count++
        console.log "confCopy:", confCopy
        unless count is 0 then @editor.setValue(confCopy)

      getProperties = (value) ->
        unless @properties?
          return []
        return ( { schema: prop, value: value[name] } for name, prop of @properties)

      getItems = (value) ->
        unless value?
          return []
        return ( { schema: @items or {}, value: v} for v in value )

      getItemLabel = (value) ->
        if @type is "object" and @properties?
          label = ""
          if @properties.name? 
            label = value.name
          if @properties.id?
            if label.length > 0
              label += " (#{value.id})"
            else
              label = value.id
          if label.length > 0 then return label
        return JSON.stringify(value)

      enhanceSchema = (schema, name) ->
        schema.name = name
        switch schema.type
          #when 'string', 'number', "integer"
          when 'object'
            schema.getProperties = getProperties
            if schema.properties?
              for name, prop of schema.properties
                enhanceSchema(prop, name)
          when 'array'
            schema.getItems = getItems
            if schema.items?
              schema.items.getItemLabel = getItemLabel
              enhanceSchema(schema.items, null)
        return

      @deviceClass.subscribe( (className) =>
        if className? and typeof className is "string" and className.length > 0
          pimatic.client.rest.getDeviceConfigSchema({className}).done( (result) =>
            if result.success?
              schema = result.configSchema
              delete schema.properties.id
              delete schema.properties.name
              delete schema.properties.class
              enhanceSchema schema, null
              @configSchema(schema)
          )
      )
      # @deviceConfig.subscribe( (config) =>
      #   editorSetConfig(config)
      # )

    resetFields: () ->
      @deviceName('')
      @deviceId('')
      @deviceConfig({})
      @deviceClass('')

    onSubmit: ->
      deviceConfig = @editor.getValue();
      deviceConfig.id = @deviceId()
      deviceConfig.name = @deviceName()
      deviceConfig.class = @deviceClass()

      (
        switch @action()
          when 'add' then pimatic.client.rest.addDeviceByConfig({deviceConfig})
          when 'update' then pimatic.client.rest.updateDeviceByConfig({deviceConfig})
          else throw new Error("Illegal devicedevice action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#devices-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s device?", @deviceName()))
      if really
        pimatic.client.rest.removeDevice({deviceId: @deviceId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#devices-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editDevice = new EditDeviceViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#edit-device-page', (event) ->
  pimatic.client.rest.getDeviceClasses({}).done( (result) =>
    if result.success
      pimatic.pages.editDevice.deviceClasses(result.deviceClasses)
  )
)


$(document).on("pagecreate", '#edit-device-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editDevice, $('#edit-device-page')[0])
  catch e
    TraceKit.report(e)
)


$(document).on("pagebeforeshow", '#edit-device-page', (event) ->
  editDevicePage = pimatic.pages.editDevice
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?.action is "update"
    device = params.device
    editDevicePage.action('update')
    editDevicePage.deviceId(device.id)
    editDevicePage.deviceName(device.name())
    editDevicePage.deviceConfig(device.config)
    editDevicePage.deviceClass(device.config.class)
  else
    editDevicePage.resetFields()
    editDevicePage.action('add')
  return
)
