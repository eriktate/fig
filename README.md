# fig
A programming language for all of the things I'm interested in building

## Why?
Mostly for fun! Also because I have minor gripes with basically every language I use and I'm curious what a language would look like if it had everything I'd like to see.

## Aren't there plenty of languages?
Yes! And many of them are super awesome! I've used a lot of languages over the years, some I love, some I like, some I tolerate, and some I loathe. Fig is based on the hope of having a language I can use for all of the things I'm interested in as side projects including:
- Games
- Tools
- Web APIs
- Web applications (I'm really not a fan of the entire JS ecosystem, but I occasionally have project ideas that require a frontend so I'd love to solve this as well)

## (Hopeful) Core features
- Manual memory management
- Simple but mighty static type system (I think Zig already does this really well so aiming for similar power)
- Developer ergonomics over safety
- Complexity embraced only when absolutely demanded and the payoff is worth it
- Really good C interop (again, Zig nails this today)

## Inspirations
The languages I'm most inspired by are Zig, C, Go, Jai, Odin, and Rust.

## Why not just use Zig?
Zig is probably the closest to being my ideal language (hence why this is written in zig), but there are a few things ranging from insanely superficial to somewhat impactful:

- Sum types. There's a bunch of things from optional values to error handling that I think sum types are a better solution for
- Logical `and` and `or`. I really dislike dropping the more traditional `&&` and `||` syntax. It bothers me more than it should every time I mistype it
- The `var` keyword. It makes sense, Go does the same thing, but it makes me think of Javascript
- Naming things. Very subjective, and zig's approach is "clever" but I personally prefer snake_case for almost everything. I think it would actually be cool to eventually automagically provide the standard library in both camelCase and snake_case, but if nothing else I prefer snake_case as the default
- Related to naming things, I really like Odin and Jai's approach to name-first identifiers. In particular I don't think Jai even requires any special keywords to declare a function and I'd probably adopt that
- Closures, functions as values, and first class functions! I actually have no idea how hard these things are to pull off in a low level, manually memory managed environment. There might be a good reason these don't really exist in zig today (and why they're really weird in Rust). If possible though, I'd like to have them
- Better, builtin string handling
- JavaScript as a first class target. I don't just want to emit and run WASM, I want a real alternative to JS in the browser
- More robust standard library. Go basically includes the entire kitchen sink. I think I'd like to at least include the faucet
- Traits. Closer to Go interfaces than Rust traits in that there's no special syntax to implement a trait. Basically any type that can be used in the same position for the same function signature can be used where a trait is expected
- Built in enum arrays. Zig accomplishes this within the standard library using comptime, but I prefer Odin's approach to native enum array support.

## Why the name?
I'm working on a game engine that I plan on porting to this language when it's done by the name of Figment. It also pays some hommage to Zig (and Odin if you squint) and is nice and short
