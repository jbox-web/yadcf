const gulp       = require('gulp');
const coffee     = require('gulp-coffee');
const coffeelint = require('gulp-coffeelint');
const eslint     = require('gulp-eslint');

gulp.task('default', () =>
  gulp.src('src/yadcf.coffee')
    .pipe(coffeelint())
    .pipe(coffeelint.reporter())
    .pipe(eslint())
    .pipe(eslint.format())
    .pipe(eslint.failAfterError())
    .pipe(coffee({bare: true}))
    .pipe(gulp.dest('dist/js'))
);
