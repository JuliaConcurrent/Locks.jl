macro exported_function(name::Symbol)
    quote
        function $name end
        export $name
    end |> esc
end
