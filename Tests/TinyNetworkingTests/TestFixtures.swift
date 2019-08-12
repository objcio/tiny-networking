import Foundation

struct Person: Codable, Equatable {
    var name: String
}

let exampleJSON = """
[
    {
        "name": "Alice"
    },
    {
        "name": "Bob"
    }
]
"""
