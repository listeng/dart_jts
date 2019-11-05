part of dart_sfs;

/// Indicates an invalid or inconsistent topological situation encountered during processing
///
/// @version 1.7
class TopologyException implements Exception {
  static String msgWithCoord(String msg, Coordinate pt) {
    if (pt != null) {
      return msg + " [ $pt ]";
    }
    return msg;
  }

  Coordinate pt;

  String msg;

  TopologyException(this.msg);

  TopologyException.withCoord(String msg, Coordinate pt) {
    this.msg = msgWithCoord(msg, pt);
    this.pt = Coordinate.fromCoordinate(pt);
  }

  Coordinate getCoordinate() {
    return pt;
  }
}

/**
 * Compares two {@link CoordinateSequence}s.
 * For sequences of the same dimension, the ordering is lexicographic.
 * Otherwise, lower dimensions are sorted before higher.
 * The dimensions compared can be limited; if this is done
 * ordinate dimensions above the limit will not be compared.
 * <p>
 * If different behaviour is required for comparing size, dimension, or
 * coordinate values, any or all methods can be overridden.
 *
 */
class CoordinateSequenceComparatorBuilder {
  static Comparator<CoordinateSequence> regular() {
    return (cs1, cs2) {
      return compare(cs1, cs2, NumberUtils.MAX_INT);
    };
  }

  static Comparator<CoordinateSequence> withLimit(int dimensionLimit) {
    return (cs1, cs2) {
      return compare(cs1, cs2, dimensionLimit);
    };
  }

  /**
   * Compare two <code>double</code>s, allowing for NaN values.
   * NaN is treated as being less than any valid number.
   *
   * @param a a <code>double</code>
   * @param b a <code>double</code>
   * @return -1, 0, or 1 depending on whether a is less than, equal to or greater than b
   */
  static int compareStatic(double a, double b) {
    if (a < b) return -1;
    if (a > b) return 1;

    if (a.isNaN) {
      if (b.isNaN) return 0;
      return -1;
    }

    if (b.isNaN) return 1;
    return 0;
  }

  /**
   * Compares two {@link CoordinateSequence}s for relative order.
   *
   * @param o1 a {@link CoordinateSequence}
   * @param o2 a {@link CoordinateSequence}
   * @return -1, 0, or 1 depending on whether o1 is less than, equal to, or greater than o2
   */
  static int compare(Object o1, Object o2, int dimensionLimit) {
    CoordinateSequence s1 = o1 as CoordinateSequence;
    CoordinateSequence s2 = o2 as CoordinateSequence;

    int size1 = s1.size();
    int size2 = s2.size();

    int dim1 = s1.getDimension();
    int dim2 = s2.getDimension();

    int minDim = dim1;
    if (dim2 < minDim) minDim = dim2;
    bool dimLimited = false;
    if (dimensionLimit <= minDim) {
      minDim = dimensionLimit;
      dimLimited = true;
    }

    // lower dimension is less than higher
    if (!dimLimited) {
      if (dim1 < dim2) return -1;
      if (dim1 > dim2) return 1;
    }

    // lexicographic ordering of point sequences
    int i = 0;
    while (i < size1 && i < size2) {
      int ptComp = compareCoordinate(s1, s2, i, minDim);
      if (ptComp != 0) return ptComp;
      i++;
    }
    if (i < size1) return 1;
    if (i < size2) return -1;

    return 0;
  }

  /**
   * Compares the same coordinate of two {@link CoordinateSequence}s
   * along the given number of dimensions.
   *
   * @param s1 a {@link CoordinateSequence}
   * @param s2 a {@link CoordinateSequence}
   * @param i the index of the coordinate to test
   * @param dimension the number of dimensions to test
   * @return -1, 0, or 1 depending on whether s1[i] is less than, equal to, or greater than s2[i]
   */
  static int compareCoordinate(CoordinateSequence s1, CoordinateSequence s2, int i, int dimension) {
    for (int d = 0; d < dimension; d++) {
      double ord1 = s1.getOrdinate(i, d);
      double ord2 = s2.getOrdinate(i, d);
      int comp = compare(ord1, ord2, dimension);
      if (comp != 0) return comp;
    }
    return 0;
  }
}

///  An interface for classes which process the coordinates in a {@link CoordinateSequence}.
///  A filter can either record information about each coordinate,
///  or change the value of the coordinate.
///  Filters can be
///  used to implement operations such as coordinate transformations, centroid and
///  envelope computation, and many other functions.
///  {@link Geometry} classes support the concept of applying a
///  <code>CoordinateSequenceFilter</code> to each
///  {@link CoordinateSequence}s they contain.
///  <p>
///  For maximum efficiency, the execution of filters can be short-circuited by using the {@link #isDone} method.
///  <p>
///  <code>CoordinateSequenceFilter</code> is
///  an example of the Gang-of-Four Visitor pattern.
///  <p>
/// <b>Note</b>: In general, it is preferable to treat Geometrys as immutable.
/// Mutation should be performed by creating a new Geometry object (see {@link GeometryEditor}
/// and {@link GeometryTransformer} for convenient ways to do this).
/// An exception to this rule is when a new Geometry has been created via {@link Geometry#copy()}.
/// In this case mutating the Geometry will not cause aliasing issues,
/// and a filter is a convenient way to implement coordinate transformation.
///
/// @see Geometry#apply(CoordinateFilter)
/// @see GeometryTransformer
/// @see GeometryEditor
///
///@see Geometry#apply(CoordinateSequenceFilter)
///@author Martin Davis
///@version 1.7
abstract class CoordinateSequenceFilter {
  /// Performs an operation on a coordinate in a {@link CoordinateSequence}.
  ///
  ///@param seq  the <code>CoordinateSequence</code> to which the filter is applied
  ///@param i the index of the coordinate to apply the filter to
  void filter(CoordinateSequence seq, int i);

  /// Reports whether the application of this filter can be terminated.
  /// Once this method returns <tt>true</tt>, it must
  /// continue to return <tt>true</tt> on every subsequent call.
  ///
  /// @return true if the application of this filter can be terminated.
  bool isDone();

  /// Reports whether the execution of this filter
  /// has modified the coordinates of the geometry.
  /// If so, {@link Geometry#geometryChanged} will be executed
  /// after this filter has finished being executed.
  /// <p>
  /// Most filters can simply return a constant value reflecting
  /// whether they are able to change the coordinates.
  ///
  /// @return true if this filter has changed the coordinates of the geometry
  bool isGeometryChanged();
}

///  An interface for classes which use the values of the coordinates in a {@link Geometry}.
/// Coordinate filters can be used to implement centroid and
/// envelope computation, and many other functions.
/// <p>
/// <code>CoordinateFilter</code> is
/// an example of the Gang-of-Four Visitor pattern.
/// <p>
/// <b>Note</b>: it is not recommended to use these filters to mutate the coordinates.
/// There is no guarantee that the coordinate is the actual object stored in the source geometry.
/// In particular, modified values may not be preserved if the source Geometry uses a non-default {@link CoordinateSequence}.
/// If in-place mutation is required, use {@link CoordinateSequenceFilter}.
///
/// @see Geometry#apply(CoordinateFilter)
/// @see CoordinateSequenceFilter
///
///@version 1.7
abstract class CoordinateFilter {
  /// Performs an operation with the provided <code>coord</code>.
  /// Note that there is no guarantee that the input coordinate
  /// is the actual object stored in the source geometry,
  /// so changes to the coordinate object may not be persistent.
  ///
  ///@param  coord  a <code>Coordinate</code> to which the filter is applied.
  void filter(Coordinate coord);
}

///  <code>GeometryCollection</code> classes support the concept of
///  applying a <code>GeometryFilter</code> to the <code>Geometry</code>.
///  The filter is applied to every element <code>Geometry</code>.
///  A <code>GeometryFilter</code> can either record information about the <code>Geometry</code>
///  or change the <code>Geometry</code> in some way.
///  <code>GeometryFilter</code>
///  is an example of the Gang-of-Four Visitor pattern.
///
///@version 1.7
abstract class GeometryFilter {
  ///  Performs an operation with or on <code>geom</code>.
  ///
  ///@param  geom  a <code>Geometry</code> to which the filter is applied.
  void filter(Geometry geom);
}

/**
 * Identifies {@link Geometry} subclasses which
 * are 0-dimensional and with components which are {@link Point}s.
 *
 * @author Martin Davis
 *
 */
abstract class Puntal {

}


/// Identifies {@link Geometry} subclasses which
/// are 2-dimensional
/// and have components which have {@link Lineal} boundaries.
///
/// @author Martin Davis
///
abstract class Polygonal {}

///  Iterates over all {@link Geometry}s in a {@link Geometry},
///  (which may be either a collection or an atomic geometry).
///  The iteration sequence follows a pre-order, depth-first traversal of the
///  structure of the <code>GeometryCollection</code>
///  (which may be nested). The original <code>Geometry</code> object is
///  returned as well (as the first object), as are all sub-collections and atomic elements.
///  It is  simple to ignore the intermediate <code>GeometryCollection</code> objects if they are not
///  needed.
///
///@version 1.7
class GeometryCollectionIterator implements Iterator {
  ///  The <code>Geometry</code> being iterated over.
  Geometry parent;

  ///  Indicates whether or not the first element
  ///  (the root <code>GeometryCollection</code>) has been returned.
  bool atStart;

  ///  The number of <code>Geometry</code>s in the the <code>GeometryCollection</code>.
  int max;

  ///  The index of the <code>Geometry</code> that will be returned when <code>next</code>
  ///  is called.
  int index;

  ///  The iterator over a nested <code>Geometry</code>, or <code>null</code>
  ///  if this <code>GeometryCollectionIterator</code> is not currently iterating
  ///  over a nested <code>GeometryCollection</code>.
  GeometryCollectionIterator subcollectionIterator;

  ///  Constructs an iterator over the given <code>Geometry</code>.
  ///
  ///@param  parent  the geometry over which to iterate; also, the first
  ///      element returned by the iterator.
  GeometryCollectionIterator(Geometry parent) {
    this.parent = parent;
    atStart = true;
    index = 0;
    max = parent.getNumGeometries();
  }

  @override
  get current => next();

  @override
  bool moveNext() {
    return hasNext();
  }

  /// Tests whether any geometry elements remain to be returned.
  ///
  /// @return true if more geometry elements remain
  bool hasNext() {
    if (atStart) {
      return true;
    }
    if (subcollectionIterator != null) {
      if (subcollectionIterator.hasNext()) {
        return true;
      }
      subcollectionIterator = null;
    }
    if (index >= max) {
      return false;
    }
    return true;
  }

  /// Gets the next geometry in the iteration sequence.
  ///
  /// @return the next geometry in the iteration
  Object next() {
    // the parent GeometryCollection is the first object returned
    if (atStart) {
      atStart = false;
      if (isAtomic(parent)) index++;
      return parent;
    }
    if (subcollectionIterator != null) {
      if (subcollectionIterator.hasNext()) {
        return subcollectionIterator.next();
      } else {
        subcollectionIterator = null;
      }
    }
    if (index >= max) {
      throw RangeError("index >= max");
    }
    Geometry obj = parent.getGeometryN(index++);
    if (obj is GeometryCollection) {
      subcollectionIterator = GeometryCollectionIterator(obj);
      // there will always be at least one element in the sub-collection
      return subcollectionIterator.next();
    }
    return obj;
  }

  static bool isAtomic(Geometry geom) {
    return !(geom is GeometryCollection);
  }

  /// Removal is not supported.
  ///
  /// @throws  UnsupportedOperationException  This method is not implemented.
  void remove() {
    throw UnsupportedError(this.runtimeType.toString());
  }
}
