//
//  main.swift
//  OCR
//
//  Created by xulihang on 2023/1/1.
//

import Vision
import Cocoa

var MODE = VNRequestTextRecognitionLevel.accurate
var USE_LANG_CORRECTION = true
var REVISION  = VNRecognizeTextRequestRevision3
func main(args: [String]) -> Int32 {
    let language = "en-US"
    var languages:[String] = []
    languages.append(language)
    let url = URL(fileURLWithPath: args[1])
    var files = [URL]()
    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                if fileAttributes.isRegularFile! && fileURL.pathExtension.lowercased().range(of: "(jpe?g|png|heic)$", options: .regularExpression) != nil {
                    files.append(fileURL)
                }
            } catch { print(error, fileURL) }
        }
        //        print(files)
    }
    
    for file in files {
        guard let img = NSImage(byReferencing: file) as NSImage? else {
            fputs("Error: failed to load image '\(file)'\n", stderr)
            return 1
        }
        guard let imgRef = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fputs("Error: failed to convert NSImage to CGImage for '\(file)'\n", stderr)
            return 1
        }
        
        let request = VNRecognizeTextRequest { (request, error) in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            var dict:[String:Any] = [:]
            var lines:[Any] = []
            var allText = ""
            var index = 0
            for observation in observations {
                // Find the top observation.
                var line:[String:Any] = [:]
                let candidate = observation.topCandidates(1).first
                let string = candidate?.string
                let confidence = candidate?.confidence
                // Find the bounding-box observation for the string range.
                let stringRange = string!.startIndex..<string!.endIndex
                let boxObservation = try? candidate?.boundingBox(for: stringRange)
                
                // Get the normalized CGRect value.
                let boundingBox = boxObservation?.boundingBox ?? .zero
                // Convert the rectangle from normalized coordinates to image coordinates.
                let rect = VNImageRectForNormalizedRect(boundingBox,
                                                        Int(imgRef.width),
                                                        Int(imgRef.height))
                
                line["text"] = string ?? ""
                line["confidence"] = confidence ?? ""
                line["x"] = Int(rect.minX)
                line["width"] = Int(rect.size.width)
                line["y"] = Int(CGFloat(imgRef.height) - rect.minY - rect.size.height)
                line["height"] = Int(rect.size.height)
                lines.append(line)
                allText = allText + (string ?? "")
                index = index + 1
                if index != observations.count {
                    allText = allText + "\n"
                }
            }
            dict["lines"] = lines
            dict["text"] = allText
            let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
            let jsonString = String(data: data!, encoding: .utf8) ?? "[]"
            let dstFile = file.absoluteString + ".json"
            do {
                try jsonString.write(to: URL(string: dstFile)!, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                print("Unexpected error writing JSON: \(error).")
                exit(1)
            }
        }
        request.recognitionLevel = MODE
        request.usesLanguageCorrection = USE_LANG_CORRECTION
        request.revision = REVISION
        request.recognitionLanguages = languages
        //request.minimumTextHeight = 0
        //request.customWords = [String]
        do {
            try VNImageRequestHandler(cgImage: imgRef, options: [:]).perform([request])
        } catch {
            print("Unexpected error with OCR: \(error).")
            exit(1)
        }
        print("\(file) done")
    }
    return 0
}

exit(main(args: CommandLine.arguments))
