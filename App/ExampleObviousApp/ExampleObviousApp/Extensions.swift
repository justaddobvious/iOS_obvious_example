//////////////////////////////////////////////////////////////////////////
// Copyright © 2019,
// 4iiii Innovations Inc.,
// Cochrane, Alberta, Canada.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are not permitted without express written approval of
// 4iiii Innovations Inc.
///////////////////////////////////////////////////////////////////////

import UIKit

/// Load images into UIImageView asynchronously
/// source: https://stackoverflow.com/questions/24231680/loading-downloading-image-from-url-on-swift
extension UIImageView {
    func download(from url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFit, completion: @escaping () -> ()) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async { [unowned self] in
                self.image = image
                completion()
            }
            }.resume()
    }
    
    func download(from link: String, contentMode mode: UIView.ContentMode = .scaleAspectFit, completion: @escaping () -> ()) {
        guard let url = URL(string: link) else  { return }
        download(from: url, contentMode: mode, completion: completion)
    }
}
