# react-native-collapsible-scroll-view

## Getting started

`$ yarn add react-native-collapsible-scroll-view`


## Usage
```javascript
import scrollViewSync from 'react-native-collapsible-scroll-view';

```

## Methods

### clearScrollViewHandle
Used to clear handles, when view is unmounted `componentDidUnmount`

### setScrollViewsHandle

```js
// Example passing nodes and measurements
scrollViewSync.setScrollViewsHandle(
        tabIndices,
        this.headerNodeHandle,
        this.state.headerHeight - TABBAR_HEIGHT,
        this.tabsScrollViewNodeHandle,
        this.tabsIndicatorViewNodeHandle,
        this.tabContentScrollViewNodeHandle,
        initialLayout.width,
        this.renderedTabsWidth
      );
```