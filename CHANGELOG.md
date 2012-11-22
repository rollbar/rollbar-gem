# Change Log

**0.4.4**
- Add `enabled` runtime config flag. When `false`, no data (messages or exceptions) will be reported.

**0.4.3**
- Add RSpec test suite. A few minor code changes.

**0.4.2**
- Add "ignore" filter level to completely ignore exceptions by class.

**0.4.1**
- Recursively filter files out of the params hash. Thanks to [trisweb](https://github.com/trisweb) for the pull request.

**0.4.0**
 
- Breaking change to make the "person" more configurable. If you were previously relying on your `current_member` method being called to return the person object, you will need to add the following line to `config/initializers/ratchetio.rb`:
    
    config.person_method = "current_member"

- Person id, username, and email method names are now configurable -- see README for details.
