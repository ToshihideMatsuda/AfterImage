
-- 以下実施手順 --
ffmpeg -i trimedMovie.mp4   -r 30  timed_framerate30_output.mp4

// https://www.adobe.com/jp/express/feature/video/resizeにてコンバート

ffmpeg -i timed_framerate30_output_AdobeExpress.mp4 -c:v libx264 -profile:v baseline -level:v 3.1 -c:a copy last_output.mp4

--iphone--
ffmpeg -i trimed.mp4   -r 30  timed_framerate30_output.mp4

ffmpeg -i timed_framerate30_886p.mp4 -c:v libx264 -profile:v baseline -level:v 3.1 -c:a copy last_output_886p.mp4

ffmpeg -i timed_framerate30_1080p.mp4 -c:v libx264 -profile:v baseline -level:v 3.1 -c:a copy last_output_1080p.mp4
--以下メモ



ffmpeg -i 886.mp4 -c:v libx264 -profile:v baseline -level:v 3.1 -c:a copy -r 30 output_886.mp4
ffmpeg -i 4-1-2.mp4  -c:v libx264 -profile:v baseline -level:v 3.1 -c:a copy -r 30  4-1-2-output.mp4

ffmepg-i trimedMovie.mp4 copy -r 30  4-1-2-output.mp4
