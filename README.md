# TinyNetworking

This package contains a tiny networking library. It provides a struct `Endpoint`, which combines a URL request and a way to parse responses for that request. Here are some examples:

## A Simple Endpoint

This is an endpoint that represents a user's data (note that there are more fields in the JSON, left out for brevity):

```swift
struct User: Codable {
    var name: String
    var location: String?
}

func userInfo(login: String) -> Endpoint<User> {
    return Endpoint(json: .get, url: URL(string: "https://api.github.com/users/\(login)")!)
}

let sample = userInfo(login: "objcio")
```

The code above is just a description of an endpoint, it does not load anything. `sample` is a simple struct, which you can inspect (for example, in a unit test).

Here's how you can load an endpoint. The `result` is of type `Result<User, Error>`.

```swift
URLSession.shared.load(endpoint) { result in
   print(result)
}
```

## Authenticated Endpoints

Here's an example of how you can have authenticated endpoints. You initialize the `Mailchimp` struct with an API key, and use that to compute an `authHeader`. You can then use the `authHeader` when you create endpoints.

```swift
struct Mailchimp {
    let base = URL(string: "https://us7.api.mailchimp.com/3.0/")!
    var apiKey = env.mailchimpApiKey
    var authHeader: [String: String] { 
        ["Authorization": "Basic " + "anystring:\(apiKey)".base64Encoded] 
    }

    func addContent(for episode: Episode, toCampaign campaignId: String) -> Endpoint<()> {
        struct Edit: Codable {
            var plain_text: String
            var html: String
        }
        let body = Edit(plain_text: plainText(episode), html: html(episode))
        let url = base.appendingPathComponent("campaigns/\(campaignId)/content")
        return Endpoint<()>(json: .put, url: url, body: body, headers: authHeader)
    }
}
```

## Custom Parsing

The JSON encoding and decoding are added as conditional extensions on top of the Codable infrastructure. However, `Endpoint` itself is not at all tied to that. Here's the type of the parsing function:

```
var parse: (Data?, URLResponse?) -> Result<A, Error>
```

Having `Data` as the input means that you can write our own functionality on top. For example, here's a resource that parses images:

```swift
struct ImageError: Error {}

extension Endpoint where A == UIImage {
    init(imageURL: URL) {
        self = Endpoint(.get, url: imageURL) { data in
            Result {
                guard let d = data, let i = UIImage(data: d) else { throw ImageError() }
                return i
            }
        }
    }
}
```

You can also write extensions that do custom JSON serialization, or parse XML, or another format.

## Testing Endpoints

Because an `Endpoint` is a plain struct, it's easy to test synchronously without a network connection. For example, you can test the image endpoint like this:

```swift
XCTAssertThrows(try Endpoint(imageURL: someURL).parse(nil, nil).get())
XCTAssertThrows(try Endpoint(imageURL: someURL).parse(invalidData, nil).get())
XCTAssertNoThrow(try Endpoint(imageURL: someURL).parse(validData, nil).get())
```

## More Examples

- In the [Swift Talk](https://talk.objc.io) backend, this is used to wrap [third-party services](https://github.com/objcio/swift-talk-backend/tree/master/Sources/SwiftTalkServerLib/ThirdPartyServices).

## More Documentation

The design and implementation of this library is covered extensively on [Swift Talk](http://talk.objc.io/). There's a collection with all the relevant episodes:

**[Networking](https://talk.objc.io/collections/networking)**

[<img src="https://talk.objc.io/assets/images/collections/Networking.svg">](https://talk.objc.io/collections/networking)

