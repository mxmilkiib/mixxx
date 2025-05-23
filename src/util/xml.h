#pragma once

class QDomNode;
class QString;
class QDomElement;
class QDomDocument;

namespace XmlParse {
// Searches for and returns a node named sNode in the children of
// nodeHeader. Returns a null QDomNode if one is not found.
QDomNode selectNode(const QDomNode& nodeHeader,
        const QString& sNode);

// Searches for and returns an element named sNode in the children of
// nodeHeader. Returns a null QDomElement if one is not found.
QDomElement selectElement(const QDomNode& nodeHeader,
        const QString& sNode);

// Searches for an element named sNode in the children of nodeHeader and
// parses the text value of its children as an integer. Returns 0 if sNode
// is not found in nodeHeader's children.
int selectNodeInt(const QDomNode& nodeHeader,
        const QString& sNode,
        bool* ok = nullptr);

// Searches for an element named sNode in the children of nodeHeader and
// parses the text value of its children as a float. Returns 0.0f if sNode
// is not found in nodeHeader's children.
float selectNodeFloat(const QDomNode& nodeHeader,
        const QString& sNode,
        bool* ok = nullptr);

// Searches for an element named sNode in the children of nodeHeader and
// parses the text value of its children as a double. Returns 0.0 if sNode
// is not found in nodeHeader's children.
double selectNodeDouble(const QDomNode& nodeHeader,
        const QString& sNode,
        bool* ok = nullptr);

// Searches for an element named sNode in the children of nodeHeader and
// parses the text value of its children as a bool. Returns false if sNode
// is not found in nodeHeader's children.
bool selectNodeBool(const QDomNode& nodeHeader,
        const QString& sNode);

// Searches for an element named sNode in the children of nodeHeader and
// returns the text value of its children. Returns the empty string if sNode
// is not found in nodeHeader's children.
QString selectNodeQString(const QDomNode& nodeHeader,
        const QString& sNode);

// Open an XML file.
QDomElement openXMLFile(const QString& path, const QString& name);

// Add an element named elementName to the provided header element with a
// child text node with the value textValue. Returns the created element.
QDomElement addElement(QDomDocument& document,
        QDomElement& header,
        const QString& elementName,
        const QString& textValue);
} // namespace XmlParse
