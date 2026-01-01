# Intrinsic Size vs Rendered Size (Step-by-Step Explanation)

This document explains **intrinsic size**, **rendered size**, and how image aspect ratios are calculated and used (with a Loox-style example) to avoid layout shifts.

---

## 📸 Example Image (From DevTools)

### Intrinsic (Actual Image File Size)

```
Width  = 375 px
Height = 500 px
```

This is the real size of the image stored on the server.

---

## 1️⃣ Step 1: Calculate the Aspect Ratio

Aspect ratio formula:

```
aspect ratio = width / height
```

Calculation:

```
375 / 500 = 0.75
```

This is written as:

```
3 : 4
```

---

## 2️⃣ Step 2: Why `data-img-ratio="1.33"`

Loox uses **height relative to width**, not width relative to height.

```
height / width = 500 / 375 = 1.3333
```

Rounded:

```
1.33
```

```html
data-img-ratio="1.33"
```

**Meaning:**  
For every `1px` of width, the image needs `1.33px` of height.

---

## 3️⃣ Step 3: Rendered Width Is Decided by Layout

From DevTools:

```
Rendered width = 263 px
```

This comes from:
- Grid or masonry column width
- Responsive layout
- CSS rules

At this point, **height is still unknown**.

---

## 4️⃣ Step 4: Rendered Height Calculation (Before Image Loads)

Loox calculates height **before** the image finishes loading:

```
renderedHeight = renderedWidth × data-img-ratio
```

Calculation:

```
263 × 1.33 = 349.79 ≈ 350 px
```

So the browser reserves:

```
Rendered size = 263 × 350 px
```

---

## 5️⃣ Step 5: Layout Is Locked

Now the browser knows the exact space the image will take:

- Masonry/grid layout is stable
- No jumping
- No reflow

---

## 6️⃣ Step 6: Image Loads

Image loads with intrinsic size:

```
375 × 500
```

Browser scales it down to:

```
263 × 350
```

✔ No layout shift  
✔ Smooth loading  
✔ No CLS (Cumulative Layout Shift)

---

## 7️⃣ What Happens Without a Ratio

### Initial render:
```
width = 263
height = auto (unknown)
```

Layout is calculated incorrectly.

### After image loads:
```
height suddenly becomes 350
```

❌ Layout shift  
❌ Masonry jump  
❌ Bad UX

---

## 8️⃣ Visual Explanation

### Without Aspect Ratio
```
┌─────┐
│     │  height unknown
└─────┘
```

### With Aspect Ratio
```
┌─────┐
│     │
│     │  height known before load
│     │
└─────┘
```

---

## 9️⃣ Recommended Implementation

### ✅ CSS (Best & Modern)

```css
.r_pw_r_image {
  width: 100%;
  aspect-ratio: 3 / 4;
  object-fit: cover;
}
```

---

### ✅ JavaScript (Loox-style)

```js
const ratio = 500 / 375; // 1.33
img.style.height = img.offsetWidth * ratio + 'px';
```

---

## 🔑 Key Takeaway

> **Images should not decide their own height after loading.  
> The layout should decide it first.**

This is how Loox avoids layout shifts and keeps masonry grids stable.
