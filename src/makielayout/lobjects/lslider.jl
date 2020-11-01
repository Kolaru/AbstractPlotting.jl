function LSlider(parent::Scene; bbox = nothing, kwargs...)

    default_attrs = default_attributes(LSlider, parent).attributes
    theme_attrs = subtheme(parent, :LSlider)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, horizontal,
        startvalue, value, color_active, color_active_dimmed, color_inactive
    )

    sliderrange = attrs.range

    protrusions = Node(GridLayoutBase.RectSides{Float32}(0, 0, 0, 0))
    layoutobservables = LayoutObservables{LSlider}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox, protrusions = protrusions)

    sliderbox = lift(identity, layoutobservables.computedbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        h = height(bb)
        w = width(bb)

        if horizontal
            y = bottom(bb) + h / 2
            [Point2f0(left(bb) + h/2, y),
             Point2f0(right(bb) - h/2, y)]
        else
            x = left(bb) + w / 2
            [Point2f0(x, bottom(bb) + w/2),
             Point2f0(x, top(bb) + h/2)]
        end
    end

    # this is the index of the selected value in the slider's range
    # selected_index = Node(1)
    # add the selected index to the attributes so it can be manipulated later
    attrs.selected_index = 1
    selected_index = attrs.selected_index

    # the fraction on the slider corresponding to the selected_index
    # this is only used after dragging
    sliderfraction = lift(selected_index, sliderrange) do i, r
        (i - 1) / (length(r) - 1)
    end

    dragging = Node(false)

    # what the slider actually displays currently (also during dragging when
    # the slider position is in an "invalid" position given the slider's range)
    displayed_sliderfraction = Node(0.0)

    on(sliderfraction) do frac
        # only update displayed fraction through sliderfraction if not dragging
        # dragging overrides the value so there is clear mouse interaction
        if !dragging[]
            displayed_sliderfraction[] = frac
        end
    end

    on(selected_index) do i
        value[] = sliderrange[][i]
    end

    # initialize slider value with closest from range
    selected_index[] = closest_index(sliderrange[], startvalue[])

    middlepoint = lift(endpoints, displayed_sliderfraction) do ep, sf
        Point2f0(ep[1] .+ sf .* (ep[2] .- ep[1]))
    end

    linepoints = lift(endpoints, middlepoint) do eps, middle
        [eps[1], middle, middle, eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ca, ci]
    end

    linewidth = lift(horizontal, sliderbox) do hori, sbox
        hori ? height(sbox) : width(sbox)
    end

    endbuttons = scatter!(parent, endpoints, color = linecolors, markersize = linewidth, strokewidth = 0, raw = true)[end]
    decorations[:endbuttons] = endbuttons

    linesegs = linesegments!(parent, linepoints, color = linecolors, linewidth = linewidth, raw = true)[end]
    decorations[:linesegments] = linesegs

    button_magnification = Node(1.0)
    buttonsize = @lift($linewidth * $button_magnification)
    button = scatter!(parent, middlepoint, color = color_active, strokewidth = 0, markersize = buttonsize, raw = true)[end]
    decorations[:button] = button

    mouseevents = addmouseevents!(parent, linesegs, button)

    onmouseleftdrag(mouseevents) do event

        dragging[] = true
        dif = event.px - event.prev_px
        fraction = if horizontal[]
            dif[1] / (endpoints[][2][1] - endpoints[][1][1])
        else
            dif[2] / (endpoints[][2][2] - endpoints[][1][2])
        end
        if fraction != 0.0f0
            newfraction = min(max(displayed_sliderfraction[] + fraction, 0f0), 1f0)
            displayed_sliderfraction[] = newfraction

            newindex = closest_fractionindex(sliderrange[], newfraction)
            if selected_index[] != newindex
                selected_index[] = newindex
            end
        end
    end

    onmouseleftdragstop(mouseevents) do event
        dragging[] = false
        # adjust slider to closest legal value
        sliderfraction[] = sliderfraction[]
        linecolors[] = [color_active_dimmed[], color_inactive[]]
    end

    onmouseleftdown(mouseevents) do event

        pos = event.px
        dim = horizontal[] ? 1 : 2
        frac = (pos[dim] - endpoints[][1][dim]) / (endpoints[][2][dim] - endpoints[][1][dim])
        selected_index[] = closest_fractionindex(sliderrange[], frac)
        # linecolors[] = [color_active[], color_inactive[]]
    end

    onmouseleftdoubleclick(mouseevents) do event
        selected_index[] = closest_index(sliderrange[], startvalue[])
    end

    onmouseenter(mouseevents) do event
        button_magnification[] = 1.25
    end

    onmouseout(mouseevents) do event
        button_magnification[] = 1.0
        linecolors[] = [color_active_dimmed[], color_inactive[]]
    end

    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    LSlider(parent, layoutobservables, attrs, decorations)
end

function valueindex(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    nothing
end

function closest_fractionindex(sliderrange, fraction)
    n = length(sliderrange)
    onestepfrac = 1 / (n - 1)
    i = round(Int, fraction / onestepfrac) + 1
    min(max(i, 1), n)
end

function closest_index(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    # if the value wasn't found this way try inexact
    closest_index_inexact(sliderrange, value)
end

function closest_index_inexact(sliderrange, value)
    distance = Inf
    selected_i = 0
    for (i, val) in enumerate(sliderrange)
        newdist = abs(val - value)
        if newdist < distance
            distance = newdist
            selected_i = i
        end
    end
    selected_i
end

"""
Set the `slider` to the value in the slider's range that is closest to `value`.
"""
function set_close_to!(slider, value)
    closest = closest_index(slider.range[], value)
    slider.selected_index = closest
end
