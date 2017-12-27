class DCJS.CreatejsDisplay.TextAnim
  constructor: (@container, @text, data) ->
    @x = data.x || 0
    @y = data.y || 0
    final_x = data.final_x || @x
    final_y = data.final_y || (@y - 30)  # No specific? Rise 30 pixels before disappearing.
    @font = data.font || "20px Arial bold"
    @color = data.color || "red"
    @duration = data.duration || 10.0
    @line_width = data.line_width || 320  # Default to something random-ish.
    duration = @duration
    container = @container

    @display_obj = new createjs.Text(@text, @font, @color)
    display_obj = @display_obj
    display_obj.lineWidth = @line_width
    display_obj.x = @x
    display_obj.y = @y
    container.addChild(display_obj)

    createjs.Tween.get(display_obj)
      .to({x: final_x, y: final_y, alpha: 0.5 }, duration * 1000.0, createjs.Ease.linear)
      .call (tween) =>
        # All done? Remove the text
        display_obj.alpha = 0.0
        display_obj.visible = false
        container.removeChild(display_obj)
