var gulp = require('gulp');
var cleanCSS = require('gulp-clean-css');
var rename = require("gulp-rename");

// Minify CSS
gulp.task('css:minify', ['sass:compile'], function() {
  return gulp.src([
      'Profiles/static/css/*.css',
      '!Profiles/static/css/*.min.css'
    ])
    .pipe(cleanCSS())
    .pipe(rename({
      suffix: '.min'
    }))
    .pipe(gulp.dest('Profiles/static/css'));
});
