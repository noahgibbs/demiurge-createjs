DCJS.CreatejsDisplay.loader = {}
loader = window.DCJS.CreatejsDisplay.loader
loader.handlers = []

loader.init = () ->
  return if loader.initialized
  # TODO: for lots of loading, see if multi-connection XHR is better/faster
  loader.queue = new createjs.LoadQueue(false)  # False to recommend tag (DOM) loading rather than XHR
  loader.queue.addEventListener "complete", loader.imagesLoaded
  loader.queue.addEventListener "error", loader.errorLoadingImages
  loader.initialized = true

loader.addHandler = (handler) ->
  loader.handlers.push handler

loader.removeHandler = (handler) ->
  index = $.inArray(handler, loader.handlers)
  loader.handlers.splice(index, 1) if index

loader.imagesLoaded = () ->
  handler() for handler in loader.handlers
  loader.handlers = []

loader.errorLoadingImages = () ->
  console.error "LOADER: Couldn't load all images!"

loader.addImages = (images...) ->
  loader.init()
  for image in images
    if image.length?
      loader.queue.loadFile(src: img, id: img) for img in image
    else
      loader.queue.loadFile(image)

loader.getImage = (image) ->
  loader.queue.getResult image
